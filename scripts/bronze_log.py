"""
GD3.4 - Metadata ingestion: bảng bronze_ingestion_log và các hàm hỗ trợ.

File này không chạy một mình. ingest_bronze.py (GD3.3) import các hàm bên dưới
để mỗi lần nạp tự ghi 1 dòng log cho mỗi bảng.

Bảng bronze_ingestion_log (mỗi lần chạy thêm đúng 9 dòng cùng một run_id):
    run_id, table_name, source_file, row_count_csv, row_count_bronze,
    schema_snapshot, load_timestamp, status, error_message, duration_seconds
"""

import csv
import json
from datetime import datetime

LOG_TABLE = "bronze_ingestion_log"


def create_log_table(con):
    con.execute(f"""
        CREATE TABLE IF NOT EXISTS {LOG_TABLE} (
            run_id            VARCHAR,
            table_name        VARCHAR,
            source_file       VARCHAR,
            row_count_csv     BIGINT,
            row_count_bronze  BIGINT,
            schema_snapshot   VARCHAR,
            load_timestamp    TIMESTAMP,
            status            VARCHAR,
            error_message     VARCHAR,
            duration_seconds  DOUBLE
        )
    """)


def count_csv_rows(path):
    """Đếm số bản ghi CSV bằng thư viện csv của Python, độc lập với DuckDB.
    csv.reader hiểu ô có dấu ngoặc kép chứa xuống dòng nên không đếm nhầm
    (khác với wc -l)."""
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        next(reader)  # bỏ dòng header
        return sum(1 for _ in reader)


def get_schema_snapshot(con, table):
    """Danh sách tên cột + kiểu của bảng dạng JSON (để sau này phát hiện schema drift)."""
    cols = con.execute(f"DESCRIBE {table}").fetchall()
    return json.dumps([{"name": c[0], "type": c[1]} for c in cols], ensure_ascii=False)


def short_error(e):
    """DuckDB hay trả lỗi rất dài nhiều dòng, chỉ giữ 2 dòng đầu cho gọn log."""
    return " | ".join(str(e).strip().splitlines()[:2])[:500]


def write_log(con, *, run_id, table_name, source_file, row_count_csv, row_count_bronze,
              schema_snapshot, status, error_message, duration_seconds):
    con.execute(
        f"INSERT INTO {LOG_TABLE} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [run_id, table_name, source_file, row_count_csv, row_count_bronze,
         schema_snapshot, datetime.now(), status, error_message, round(duration_seconds, 2)],
    )
