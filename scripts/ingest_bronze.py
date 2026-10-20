"""
GD3.3 - Nạp dữ liệu thô Olist vào tầng Bronze (MotherDuck).

Cách chạy (từ đâu cũng được):
    python scripts/ingest_bronze.py

Cần có:
    - file .env ở thư mục gốc repo:  MOTHERDUCK_TOKEN=...
    - 9 file CSV Olist trong data/raw/

Nguyên tắc Bronze:
  - Giữ nguyên dữ liệu gốc: mọi cột đọc là VARCHAR (all_varchar), việc ép kiểu để Silver làm.
  - Append-only: mỗi lần chạy INSERT thêm dòng mới, không xóa/ghi đè lần trước.
  - Mỗi dòng gắn 3 cột metadata: _load_timestamp, _source_file, _run_id.
  - Mỗi bảng ghi 1 dòng vào bronze_ingestion_log (xem bronze_log.py, GD3.4).
"""

import argparse
import os
import sys
import time
import uuid
from datetime import datetime
from pathlib import Path

# Cấu hình UTF-8 cho console Windows ngay đầu file (tránh UnicodeEncodeError khi in tiếng Việt hoặc --help)
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

import duckdb

# Thư mục gốc repo và thư mục scripts (hỗ trợ import cả khi chạy từ root hoặc scripts/)
SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
for p in (str(ROOT), str(SCRIPT_DIR)):
    if p not in sys.path:
        sys.path.insert(0, p)

# Nạp .env ngay đầu module để các hàm kết nối luôn sẵn sàng biến môi trường
try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / ".env")
except ImportError:
    load_dotenv = None

# Import từ bronze_log (hỗ trợ import trực tiếp hoặc qua package scripts)
try:
    from bronze_log import (count_csv_rows, create_log_table, get_schema_snapshot,
                            short_error, write_log)
except ImportError:
    from scripts.bronze_log import (count_csv_rows, create_log_table, get_schema_snapshot,
                                    short_error, write_log)


# Tên file CSV -> tên bảng Bronze
TABLES = {
    "olist_customers_dataset.csv": "bronze_customers",
    "olist_geolocation_dataset.csv": "bronze_geolocation",
    "olist_order_items_dataset.csv": "bronze_order_items",
    "olist_order_payments_dataset.csv": "bronze_order_payments",
    "olist_order_reviews_dataset.csv": "bronze_order_reviews",
    "olist_orders_dataset.csv": "bronze_orders",
    "olist_products_dataset.csv": "bronze_products",
    "olist_sellers_dataset.csv": "bronze_sellers",
    "product_category_name_translation.csv": "bronze_product_category_name_translation",
}

DEFAULT_DB = "md:olist_warehouse"


def connect(target):
    """Kết nối MotherDuck (md:...) hoặc file DuckDB local (dùng để test)."""
    if target.startswith("md:"):
        token = os.environ.get("MOTHERDUCK_TOKEN")
        if not token or token.strip() == "":
            sys.exit("Thiếu MOTHERDUCK_TOKEN. Thêm dòng MOTHERDUCK_TOKEN=... vào file .env "
                     "ở thư mục gốc repo (hoặc set biến môi trường).")
        token = token.strip()
        os.environ["motherduck_token"] = token
        os.environ["MOTHERDUCK_TOKEN"] = token
        db_name = target[3:].strip() or os.environ.get("MOTHERDUCK_DATABASE", "olist_warehouse").strip()
        con = duckdb.connect(f"md:?motherduck_token={token}")
        con.execute(f"CREATE DATABASE IF NOT EXISTS {db_name}")
        con.execute(f"USE {db_name}")
        return con
    return duckdb.connect(target)


def read_csv_sql(path):
    """Câu SELECT đọc 1 file CSV, thêm 3 cột metadata (giá trị truyền qua tham số)."""
    safe_path = Path(path).resolve().as_posix().replace("'", "''")
    # order_reviews có ô chứa dấu " và xuống dòng, nên khai báo quote/escape rõ ràng
    extra = ", quote='\"', escape='\"'" if "order_reviews" in Path(path).name else ""
    return f"""
        SELECT *,
               ?::TIMESTAMP AS _load_timestamp,
               ? AS _source_file,
               ? AS _run_id
        FROM read_csv('{safe_path}', header=true, all_varchar=true{extra})
    """


def load_table(con, csv_path, table, run_id, row_count_csv):
    """Nạp 1 bảng, trả về số dòng Bronze nhận được trong lần chạy này."""
    select_sql = read_csv_sql(csv_path)
    params = [datetime.now(), csv_path.name, run_id]

    # Tạo bảng nếu chưa có (lấy cấu trúc cột từ CSV, 0 dòng)
    con.execute(f"CREATE TABLE IF NOT EXISTS {table} AS {select_sql} LIMIT 0", params)

    # INSERT trong transaction: nếu số dòng không khớp thì rollback, bảng không bị nạp dở.
    # BY NAME: CSV đổi tên cột (schema drift) sẽ báo lỗi thay vì nạp lệch cột.
    con.execute("BEGIN TRANSACTION")
    try:
        con.execute(f"INSERT INTO {table} BY NAME {select_sql}", params)
        row_count_bronze = con.execute(
            f"SELECT count(*) FROM {table} WHERE _run_id = ?", [run_id]
        ).fetchone()[0]
        if row_count_bronze != row_count_csv:
            raise ValueError(
                f"Số dòng không khớp: CSV có {row_count_csv}, Bronze nhận {row_count_bronze}"
            )
        con.execute("COMMIT")
    except Exception:
        con.execute("ROLLBACK")
        raise
    return row_count_bronze


def main():
    parser = argparse.ArgumentParser(description="Nạp 9 file CSV Olist vào Bronze")
    parser.add_argument("--data-dir", default=str(ROOT / "data" / "raw"),
                        help="Thư mục chứa 9 file CSV (mặc định: <repo>/data/raw)")
    parser.add_argument("--db", default=DEFAULT_DB,
                        help="md:<tên_db> cho MotherDuck, hoặc đường dẫn file .duckdb để test")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    con = connect(args.db)
    create_log_table(con)

    # run_id sinh một lần cho cả lần chạy, dùng chung cho 9 bảng
    run_id = f"{datetime.now():%Y%m%d_%H%M%S}_{uuid.uuid4().hex[:6]}"
    print(f"Bắt đầu run_id = {run_id}")

    failed = 0
    for file_name, table in TABLES.items():
        started = time.time()
        csv_path = data_dir / file_name
        rows_csv = rows_bronze = schema_snapshot = None
        try:
            if not csv_path.exists():
                raise FileNotFoundError(f"Không thấy file {csv_path}")
            # đếm CSV trước, để lỗi ở bước sau vẫn còn row_count_csv trong log
            rows_csv = count_csv_rows(csv_path)
            rows_bronze = load_table(con, csv_path, table, run_id, rows_csv)
            schema_snapshot = get_schema_snapshot(con, table)
            status, error_message = "SUCCESS", None
            print(f"  OK     {table:42s} {rows_bronze:>10,} dòng  {time.time() - started:6.1f}s")
        except Exception as e:
            # Lỗi thì ghi FAILED rồi chạy tiếp bảng sau
            failed += 1
            status, error_message = "FAILED", short_error(e)
            print(f"  FAILED {table:42s} {error_message}")

        write_log(con, run_id=run_id, table_name=table, source_file=file_name,
                  row_count_csv=rows_csv, row_count_bronze=rows_bronze,
                  schema_snapshot=schema_snapshot, status=status,
                  error_message=error_message, duration_seconds=time.time() - started)

    print(f"Xong run_id = {run_id}: {len(TABLES) - failed} thành công, {failed} lỗi")
    con.close()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
