"""
Kiểm tra dữ liệu trên MotherDuck trước khi làm 04_ml_clustering.ipynb.

Cách chạy (đứng ở thư mục gốc repo, nơi có file .env):
    python scripts/check_ml_readiness.py

Kết quả: file ml_readiness_report.md ở thư mục gốc repo -> gửi file này cho Claude.
Script chỉ ĐỌC dữ liệu, không tạo/sửa/xóa bảng nào.

Tùy chọn khi test local:
    python scripts/check_ml_readiness.py --db path/to/file.duckdb
"""

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path

import duckdb

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # không có python-dotenv thì đọc biến môi trường sẵn có


report_lines = []


def out(text=""):
    print(text)
    report_lines.append(text)


class Result:
    """Kết quả truy vấn gọn nhẹ, không cần pandas."""
    def __init__(self, cols, rows):
        self.cols, self.rows = cols, rows

    def __len__(self):
        return len(self.rows)

    def col(self, name):
        i = self.cols.index(name)
        return [r[i] for r in self.rows]


def q(con, sql, params=None):
    cur = con.execute(sql, params or [])
    return Result([d[0] for d in cur.description], cur.fetchall())


def table_md(res, max_rows=50):
    if res is None or len(res) == 0:
        return "_(không có dòng nào)_"
    lines = ["| " + " | ".join(str(c) for c in res.cols) + " |",
             "|" + "---|" * len(res.cols)]
    for row in res.rows[:max_rows]:
        lines.append("| " + " | ".join("" if v is None else str(v) for v in row) + " |")
    return "\n".join(lines)


def connect(local_db):
    if local_db:
        return duckdb.connect(local_db, read_only=True)
    token = os.getenv("MOTHERDUCK_TOKEN")
    db_name = os.getenv("MOTHERDUCK_DATABASE", "olist_warehouse")
    if not token:
        sys.exit("Không thấy MOTHERDUCK_TOKEN. Kiểm tra file .env ở thư mục gốc repo.")
    return duckdb.connect(f"md:{db_name}", config={"motherduck_token": token})


def find_tables(con):
    """Trả về dict: tên bảng -> 'schema.table' (lấy bản đầu tiên tìm thấy)."""
    res = q(con, """
        SELECT table_schema, table_name, table_type
        FROM information_schema.tables
        WHERE table_catalog = current_database()
          AND table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY table_schema, table_name
    """)
    found = {}
    for schema, table, _ in res.rows:
        found.setdefault(table, f'"{schema}"."{table}"')
    return res, found


def columns_of(con, full_name):
    schema, table = [p.strip('"') for p in full_name.split(".")]
    return q(con, """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_catalog = current_database()
          AND table_schema = ? AND table_name = ?
        ORDER BY ordinal_position
    """, [schema, table])


def run_check(con, title, sql, note=None):
    out(f"\n### {title}")
    if note:
        out(f"_{note}_")
    try:
        out(table_md(q(con, sql)))
    except Exception as e:
        out(f"**LỖI:** `{str(e).splitlines()[0]}`")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", help="đường dẫn file .duckdb local (bỏ trống = MotherDuck)")
    parser.add_argument("--dbt-dir", default="dbt_olist", help="thư mục dbt project")
    parser.add_argument("--out", default="ml_readiness_report.md")
    args = parser.parse_args()

    con = connect(args.db)
    out("# ML readiness report")
    out(f"Thời điểm chạy: {datetime.now():%Y-%m-%d %H:%M}")
    out(f"Database: {con.execute('SELECT current_database()').fetchone()[0]}")

    # ---------- 1. Danh sách bảng ----------
    out("\n## 1. Bảng/view hiện có")
    all_tables, t = find_tables(con)
    out(table_md(all_tables, max_rows=200))

    needed = ["fact_sales", "fact_customer_reviews", "dim_customer", "dim_date",
              "silver_orders", "silver_order_payments"]
    missing = [n for n in needed if n not in t]
    out(f"\nThiếu: {', '.join(missing) if missing else 'không thiếu bảng nào'}")

    # ---------- 2. Số dòng + cột ----------
    out("\n## 2. Số dòng và danh sách cột")
    for name in needed + [n for n in t if "customer_3" in n or "rfm" in n or "mart" in n]:
        if name not in t:
            continue
        try:
            n = con.execute(f"SELECT COUNT(*) FROM {t[name]}").fetchone()[0]
        except Exception as e:
            n = f"LỖI {e}"
        out(f"\n### {t[name]} — {n:,} dòng" if isinstance(n, int) else f"\n### {t[name]} — {n}")
        cols = columns_of(con, t[name])
        out(", ".join(f"{c} ({d})" for c, d in cols.rows))

    if "fact_sales" not in t or "dim_customer" not in t:
        out("\n**Chưa có fact_sales hoặc dim_customer trên MotherDuck -> cần chạy dbt cho tầng Gold trước.**")
        save(args.out)
        return

    fs, dc = t["fact_sales"], t["dim_customer"]
    fs_cols = set(columns_of(con, fs).col("column_name"))

    # ---------- 3. Cột giao hàng ----------
    out("\n## 3. Cột giao hàng trong fact_sales")
    for c in ["delivery_days", "delivery_delay_days", "is_late",
              "estimated_delivery_date_key", "delivered_date_key"]:
        out(f"- {c}: {'CÓ' if c in fs_cols else 'KHÔNG'}")

    # ---------- 4. Kiểm tra dữ liệu cho ML ----------
    out("\n## 4. Kiểm tra dữ liệu cho phân cụm")

    run_check(con, "4.1 Đối soát số dòng/khách", f"""
        SELECT
          (SELECT COUNT(*) FROM {fs}) AS fact_sales_rows,
          (SELECT COUNT(DISTINCT order_id) FROM {fs}) AS orders_in_fact,
          (SELECT COUNT(DISTINCT customer_unique_id) FROM {fs}) AS customers_in_fact,
          (SELECT COUNT(*) FROM {dc}) AS dim_customer_rows,
          (SELECT COUNT(DISTINCT customer_unique_id) FROM {dc}) AS dim_customer_distinct
    """, "Kỳ vọng: 112,650 dòng fact; 96,096 khách")

    run_check(con, "4.2 Phân bố trạng thái đơn trong fact_sales", f"""
        SELECT order_status, COUNT(DISTINCT order_id) AS n_orders
        FROM {fs} GROUP BY 1 ORDER BY 2 DESC
    """)

    run_check(con, "4.3 Phân bố Frequency (đơn delivered / khách)", f"""
        WITH f AS (
          SELECT customer_unique_id, COUNT(DISTINCT order_id) AS freq
          FROM {fs} WHERE order_status = 'delivered' GROUP BY 1
        )
        SELECT freq, COUNT(*) AS n_customers,
               ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
        FROM f GROUP BY 1 ORDER BY 1
    """)

    run_check(con, "4.4 Khách không có đơn delivered nào", f"""
        SELECT COUNT(*) AS customers_without_delivered
        FROM {dc} d
        WHERE NOT EXISTS (
          SELECT 1 FROM {fs} s
          WHERE s.customer_unique_id = d.customer_unique_id
            AND s.order_status = 'delivered')
    """)

    if "dim_date" in t:
        dd = t["dim_date"]
        run_check(con, "4.5 Ứng viên snapshot_date (ngày tham chiếu Recency)", f"""
            SELECT
              MAX(d.full_date) FILTER (WHERE s.order_status = 'delivered') AS max_purchase_delivered,
              MAX(d.full_date) AS max_purchase_all,
              MIN(d.full_date) AS min_purchase_all
            FROM {fs} s JOIN {dd} d ON s.purchase_date_key = d.date_key
        """)

    run_check(con, "4.6 Phân bố Monetary = SUM(price) đơn delivered / khách", f"""
        WITH m AS (
          SELECT customer_unique_id, SUM(price) AS monetary
          FROM {fs} WHERE order_status = 'delivered' GROUP BY 1
        )
        SELECT COUNT(*) AS n, ROUND(MIN(monetary),2) AS min,
               ROUND(quantile_cont(monetary, 0.25),2) AS q1,
               ROUND(median(monetary),2) AS median,
               ROUND(quantile_cont(monetary, 0.75),2) AS q3,
               ROUND(quantile_cont(monetary, 0.99),2) AS p99,
               ROUND(MAX(monetary),2) AS max,
               ROUND(skewness(monetary),2) AS skew
        FROM m
    """)

    run_check(con, "4.7 So sánh 3 cách đo Monetary (đơn delivered)", f"""
        SELECT ROUND(SUM(price),2) AS sum_price,
               ROUND(SUM(gmv),2) AS sum_gmv,
               ROUND(SUM(allocated_payment_value),2) AS sum_payment
        FROM {fs} WHERE order_status = 'delivered'
    """)

    if "fact_customer_reviews" in t:
        fr = t["fact_customer_reviews"]
        run_check(con, "4.8 Độ phủ review theo khách (khách có đơn delivered)", f"""
            WITH c AS (SELECT DISTINCT customer_unique_id FROM {fs} WHERE order_status='delivered'),
                 r AS (SELECT DISTINCT customer_unique_id FROM {fr})
            SELECT COUNT(*) AS customers_delivered,
                   COUNT(r.customer_unique_id) AS customers_with_review,
                   ROUND(100.0 * COUNT(r.customer_unique_id) / COUNT(*), 2) AS pct_with_review
            FROM c LEFT JOIN r USING (customer_unique_id)
        """)

    if "silver_order_payments" in t:
        run_check(con, "4.9 Đối soát fan-out: payment phân bổ vs payment nguồn", f"""
            SELECT ROUND((SELECT SUM(allocated_payment_value) FROM {fs}),2) AS gold_allocated,
                   ROUND((SELECT SUM(payment_value) FROM {t['silver_order_payments']}
                          WHERE order_id IN (SELECT order_id FROM {fs})),2) AS silver_payment
        """, "Hai số phải bằng nhau")

    if "silver_orders" in t:
        so = t["silver_orders"]
        so_cols = set(columns_of(con, so).col("column_name"))
        out("\n### 4.10 Cột ngày giao trong silver_orders")
        for c in ["order_delivered_customer_date", "order_estimated_delivery_date",
                  "is_valid_chronology", "is_delivery_missing"]:
            out(f"- {c}: {'CÓ' if c in so_cols else 'KHÔNG'}")
        if {"order_delivered_customer_date", "order_estimated_delivery_date"} <= so_cols:
            run_check(con, "4.11 Thử tính delivery features từ silver_orders", f"""
                SELECT COUNT(*) AS delivered_orders,
                       COUNT(order_delivered_customer_date) AS has_delivered_date,
                       ROUND(AVG(date_diff('day', order_purchase_timestamp,
                             order_delivered_customer_date)),2) AS avg_delivery_days,
                       ROUND(100.0 * AVG(CASE WHEN order_delivered_customer_date
                             > order_estimated_delivery_date THEN 1 ELSE 0 END),2) AS pct_late
                FROM {so} WHERE order_status = 'delivered'
            """)

    # ---------- 5. File dbt ----------
    out("\n## 5. Mã nguồn dbt liên quan")
    dbt_dir = Path(args.dbt_dir)
    if not dbt_dir.exists():
        out(f"_Không thấy thư mục {dbt_dir} (chạy script ở thư mục gốc repo)._")
    else:
        keys = ("fact_sales", "dim_customer", "fact_customer_reviews", "customer_3", "rfm", "mart")
        files = [p for p in dbt_dir.rglob("*")
                 if p.is_file() and p.suffix in (".sql", ".yml")
                 and "target" not in p.parts and "dbt_packages" not in p.parts
                 and (any(k in p.name for k in keys) or p.name in ("schema.yml", "dbt_project.yml"))]
        for p in sorted(files):
            out(f"\n### {p}")
            out("```" + ("sql" if p.suffix == ".sql" else "yaml"))
            out(p.read_text(encoding="utf-8", errors="replace")[:15000])
            out("```")

    save(args.out)


def save(path):
    Path(path).write_text("\n".join(report_lines), encoding="utf-8")
    print(f"\n==> Đã ghi {path}. Gửi file này cho Claude.")


if __name__ == "__main__":
    main()