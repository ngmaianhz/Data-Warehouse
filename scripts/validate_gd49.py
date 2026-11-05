"""GD4.9 read-only reconciliation of current Olist marts on MotherDuck.
Run from repo root: python scripts/validate_gd49.py
Requires: duckdb, python-dotenv. Never modifies the database.
"""
from __future__ import annotations
import csv
import os
import sys
from datetime import datetime
from decimal import Decimal
from pathlib import Path

import duckdb
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / '.env', override=True)
OUT = ROOT / 'docs' / 'GD4.9_evidence'
OUT.mkdir(parents=True, exist_ok=True)
TOKEN = os.getenv('MOTHERDUCK_TOKEN')
DATABASE = os.getenv('MOTHERDUCK_DATABASE', 'olist_warehouse').strip()
if not TOKEN:
    sys.exit('ERROR: MOTHERDUCK_TOKEN missing in repository .env')

# SELECT only: no DDL, DML or dbt build; works with read-only access.
con = duckdb.connect('md:' + DATABASE, config={'motherduck_token': TOKEN})

def table_ref(name: str) -> str:
    rows = con.execute('''
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE lower(table_name) = lower(?)
          AND table_schema NOT IN ('information_schema', 'pg_catalog')
    ''', [name]).fetchall()
    if len(rows) != 1:
        raise RuntimeError(f'Expected exactly one table/view {name}; found {rows}. Check current dbt schema and permissions.')
    schema, table = rows[0]
    return f'"{schema.replace(chr(34), chr(34)*2)}"."{table.replace(chr(34), chr(34)*2)}"'

f = table_ref('fact_sales')
m = table_ref('mart_customer_360')
r = table_ref('mart_customer_rfm')
d = table_ref('dim_customer')
c = table_ref('dim_customer_cluster')


def query(sql: str):
    cur = con.execute(sql)
    columns = [c[0] for c in cur.description]
    return columns, cur.fetchall()


def save_csv(filename: str, sql: str):
    cols, rows = query(sql)
    with (OUT / filename).open('w', encoding='utf-8-sig', newline='') as fp:
        writer = csv.writer(fp)
        writer.writerow(cols)
        writer.writerows(rows)
    print(f'[OK] {filename}: {len(rows)} rows')
    return cols, rows

# (1) Fixed reproducible sample: the same 10 IDs can be rechecked manually.
# Critical: price maps to total_revenue, and gmv maps to total_gmv.
sample_cte = f'''
WITH sample_ids AS (
    SELECT customer_unique_id
    FROM {m}
    ORDER BY hash(customer_unique_id), customer_unique_id
    LIMIT 10
), fact_sample AS (
    SELECT f.customer_unique_id,
           CAST(ROUND(SUM(f.price), 2) AS DECIMAL(18,2)) AS fact_revenue,
           CAST(ROUND(SUM(f.gmv), 2) AS DECIMAL(18,2)) AS fact_gmv,
           COUNT(DISTINCT f.order_id) AS fact_orders
    FROM {f} f
    JOIN sample_ids s ON f.customer_unique_id = s.customer_unique_id
    WHERE f.order_status = 'delivered'
    GROUP BY f.customer_unique_id
)
'''

sample_cols, sample_rows = save_csv('01_customer_sample_reconciliation.csv', sample_cte + f'''
SELECT s.customer_unique_id,
       a.fact_revenue, m.total_revenue AS mart_revenue,
       ROUND(a.fact_revenue - m.total_revenue, 2) AS revenue_delta,
       a.fact_gmv, m.total_gmv AS mart_gmv,
       ROUND(a.fact_gmv - m.total_gmv, 2) AS gmv_delta,
       a.fact_orders, m.total_orders AS mart_orders,
       a.fact_orders - m.total_orders AS orders_delta
FROM sample_ids s
JOIN fact_sample a USING (customer_unique_id)
JOIN {m} m USING (customer_unique_id)
ORDER BY s.customer_unique_id
''')

save_csv('01b_customer_sample_fact_items.csv', sample_cte + f'''
SELECT f.customer_unique_id, f.order_id, f.order_item_id,
       f.order_status, f.price, f.freight_value, f.gmv
FROM {f} f
JOIN sample_ids s USING (customer_unique_id)
WHERE f.order_status = 'delivered'
ORDER BY f.customer_unique_id, f.order_id, f.order_item_id
''')

# (2)/(4) Three expected-zero checks, PLUS a separate correct revenue check.
metrics_cols, metrics_rows = save_csv('02_global_reconciliation.csv', f'''
WITH a AS (
 SELECT CAST(ROUND(SUM(price),2) AS DECIMAL(18,2)) AS fact_revenue,
        CAST(ROUND(SUM(gmv),2) AS DECIMAL(18,2)) AS fact_gmv,
        COUNT(DISTINCT order_id) AS fact_orders,
        COUNT(DISTINCT customer_unique_id) AS fact_customers,
        COUNT(DISTINCT CASE WHEN customer_unique_id IS NULL THEN order_id END) AS orders_missing_customer
 FROM {f}
 WHERE order_status = 'delivered'
), b AS (
 SELECT CAST(ROUND(SUM(total_revenue),2) AS DECIMAL(18,2)) AS mart_revenue,
        CAST(ROUND(SUM(total_gmv),2) AS DECIMAL(18,2)) AS mart_gmv,
        SUM(total_orders) AS mart_orders,
        COUNT(*) AS mart_customers,
        COUNT(DISTINCT customer_unique_id) AS mart_distinct_customers
 FROM {m}
)
SELECT a.*, b.*,
 ROUND(b.mart_revenue - a.fact_revenue, 2) AS delta_revenue_correct,
 ROUND(b.mart_gmv - a.fact_gmv, 2) AS delta_gmv,
 b.mart_orders - a.fact_orders AS delta_orders,
 b.mart_customers - a.fact_customers AS delta_customers,
 b.mart_customers - b.mart_distinct_customers AS delta_duplicate_mart_customers,
 ROUND(b.mart_revenue - a.fact_gmv, 2) AS delta_revenue_vs_gmv_not_expected_zero
FROM a CROSS JOIN b
''')

# (3) Current schema has no R/F/M scores or segment; export raw RFM and K-Means cluster distribution.
rfm_cols = {x[0] for x in con.execute(f'SELECT * FROM {r} LIMIT 0').description}
# Validate that RFM features are exactly those defined in the current SQL model.
rfm_check_cols, rfm_check_rows = save_csv('03_rfm_consistency.csv', f''' 
WITH base AS (
 SELECT m.customer_unique_id, m.total_orders, m.total_gmv, m.last_order_date,
        CAST(date_diff('day', m.last_order_date, MAX(m.last_order_date) OVER ()) AS INTEGER) AS expected_recency
 FROM {m} m
), discrepancies AS (
 SELECT b.customer_unique_id,
        CASE WHEN r.customer_unique_id IS NULL THEN 1 ELSE 0 END AS missing_rfm,
        CASE WHEN r.customer_unique_id IS NOT NULL AND r.recency_days IS DISTINCT FROM b.expected_recency THEN 1 ELSE 0 END AS wrong_recency,
        CASE WHEN r.customer_unique_id IS NOT NULL AND r.frequency IS DISTINCT FROM b.total_orders THEN 1 ELSE 0 END AS wrong_frequency,
        CASE WHEN r.customer_unique_id IS NOT NULL AND r.monetary IS DISTINCT FROM b.total_gmv THEN 1 ELSE 0 END AS wrong_monetary
 FROM base b LEFT JOIN {r} r USING (customer_unique_id)
)
SELECT COUNT(*) AS customer_360_count,
       (SELECT COUNT(*) FROM {r}) AS rfm_row_count,
       (SELECT COUNT(DISTINCT customer_unique_id) FROM {r}) AS rfm_unique_count,
       SUM(missing_rfm) AS missing_rfm,
       SUM(wrong_recency) AS wrong_recency,
       SUM(wrong_frequency) AS wrong_frequency,
       SUM(wrong_monetary) AS wrong_monetary
FROM discrepancies
''')

save_csv('03_rfm_frequency_distribution.csv', f'''
SELECT frequency, COUNT(*) AS customer_count
FROM {r}
GROUP BY frequency ORDER BY frequency
''')
save_csv('03_rfm_recency_distribution.csv', f'''
SELECT recency_days, COUNT(*) AS customer_count
FROM {r}
GROUP BY recency_days ORDER BY recency_days
''')
save_csv('03_rfm_monetary_summary.csv', f'''
SELECT COUNT(*) AS customer_count, MIN(monetary) AS min_monetary,
       ROUND(AVG(monetary),2) AS avg_monetary,
       MEDIAN(monetary) AS median_monetary,
       MAX(monetary) AS max_monetary
FROM {r}
''')
if 'cluster_id' in rfm_cols:
    cluster_cols, cluster_rows = save_csv('03_cluster_distribution.csv', f'''
    SELECT cluster_id, COUNT(*) AS customer_count,
           ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),2) AS pct
    FROM {r}
    GROUP BY cluster_id ORDER BY cluster_id
    ''')
else:
    cluster_cols, cluster_rows = [], []
cluster_profile_cols, cluster_profile_rows = save_csv('03_cluster_profile_reconciliation.csv', f'''
WITH observed AS (
 SELECT cluster_id, COUNT(*) AS observed_customers,
        CAST(ROUND(SUM(monetary), 2) AS DECIMAL(18,2)) AS observed_monetary
 FROM {r} GROUP BY cluster_id
)
SELECT COALESCE(o.cluster_id, d.cluster_id) AS cluster_id,
       d.cluster_label,
       COALESCE(o.observed_customers,0) AS observed_customers,
       d.n_customers AS profile_customers,
       COALESCE(o.observed_customers,0) - COALESCE(d.n_customers,0) AS delta_customers,
       o.observed_monetary, d.sum_monetary,
       ROUND(COALESCE(o.observed_monetary,0) - COALESCE(d.sum_monetary,0),2) AS delta_monetary
FROM observed o FULL OUTER JOIN {c} d ON o.cluster_id = d.cluster_id
ORDER BY cluster_id
''')

if {'r_score', 'f_score', 'm_score', 'segment'} <= rfm_cols:
    for score in ['r_score', 'f_score', 'm_score']:
        save_csv(f'03_{score}_distribution.csv', f'''
        SELECT {score}, COUNT(*) AS customer_count
        FROM {r} GROUP BY {score} ORDER BY {score}
        ''')
    save_csv('03_segment_distribution.csv', f'''
    SELECT segment, COUNT(*) AS customer_count
    FROM {r} GROUP BY segment ORDER BY customer_count DESC
    ''')
else:
    print('[INFO] Scores/segment not present in current mart_customer_rfm; see report.')

# (5) Two scopes: mart delivered-only vs dimension all order statuses.
first_cols, first_rows = save_csv('04_first_order_date_comparison.csv', f'''
SELECT m.customer_unique_id, m.first_order_date AS first_delivered_purchase_date,
       CAST(d.first_order_date AS DATE) AS first_any_status_purchase_date,
       date_diff('day', CAST(d.first_order_date AS DATE), m.first_order_date) AS date_gap_days
FROM {m} m JOIN {d} d USING (customer_unique_id)
WHERE m.first_order_date IS DISTINCT FROM CAST(d.first_order_date AS DATE)
ORDER BY ABS(date_gap_days) DESC, m.customer_unique_id
LIMIT 20
''')
first_summary_cols, first_summary_rows = save_csv('04_first_order_date_summary.csv', f'''
SELECT COUNT(*) AS customers_in_mart,
 COUNT(*) FILTER (WHERE d.customer_unique_id IS NULL) AS missing_in_dim,
 COUNT(*) FILTER (WHERE m.first_order_date = CAST(d.first_order_date AS DATE)) AS equal_dates,
 COUNT(*) FILTER (WHERE m.first_order_date > CAST(d.first_order_date AS DATE)) AS mart_later,
 COUNT(*) FILTER (WHERE m.first_order_date < CAST(d.first_order_date AS DATE)) AS mart_earlier,
 COUNT(*) FILTER (WHERE d.first_order_date IS NULL) AS dim_null_dates
FROM {m} m LEFT JOIN {d} d USING (customer_unique_id)
''')

# (6) Count orders, not fact item rows.
missing_cols, missing_rows = save_csv('05_delivered_missing_date.csv', f'''
SELECT COUNT(DISTINCT order_id) AS delivered_orders_with_date_key_minus_1,
       COUNT(*) AS fact_item_rows_with_date_key_minus_1
FROM {f}
WHERE order_status = 'delivered' AND delivered_date_key = -1
''')

values = dict(zip(metrics_cols, metrics_rows[0]))
checks = ['delta_revenue_correct', 'delta_gmv', 'delta_orders', 'delta_customers', 'delta_duplicate_mart_customers']
sample_failed = any(any(row[sample_cols.index(col)] != 0 for col in ('revenue_delta', 'gmv_delta', 'orders_delta')) for row in sample_rows)
failures = [x for x in checks if values[x] != 0]
if sample_failed: failures.append('customer_sample_deltas')
rfm_summary = dict(zip(rfm_check_cols, rfm_check_rows[0]))
for field in ('missing_rfm','wrong_recency','wrong_frequency','wrong_monetary'):
    if rfm_summary[field] != 0: failures.append('rfm_' + field)
if rfm_summary['customer_360_count'] != rfm_summary['rfm_row_count'] or rfm_summary['rfm_row_count'] != rfm_summary['rfm_unique_count']:
    failures.append('rfm_grain')
# -1 is the unassigned placeholder, for which profile counts can legitimately be zero.
# Profile may be from a prior clustering run: flag its mismatch for review, not a core reconciliation failure.
cluster_profile_mismatches = [row for row in cluster_profile_rows if row[0] != -1 and (row[4] != 0 or row[7] != 0)]


def md_table(cols, rows, limit=20):
    if not rows: return '_Không có dòng._\n'
    lines = ['| ' + ' | '.join(cols) + ' |', '| ' + ' | '.join(['---']*len(cols)) + ' |']
    for row in rows[:limit]:
        lines.append('| ' + ' | '.join(str(x) if x is not None else 'NULL' for x in row) + ' |')
    return '\n'.join(lines) + '\n'

report = f'''# GD4.9 — Kiểm chứng & đối soát (kết quả truy vấn thực tế)

- Database: MotherDuck `{DATABASE}`; chạy lúc: {datetime.now().astimezone().isoformat(timespec='seconds')}.
- Chỉ chạy SELECT, không cập nhật dữ liệu. Bảng thực tế: `{f}`, `{m}`, `{r}`, `{d}`.
- Kết quả tự động: **{'PASS' if not failures else 'REVIEW / FAIL'}**. Kiểm tra: {', '.join(failures) if failures else 'tất cả sai lệch kỳ vọng 0 đều bằng 0'}.

## 1. Đối soát 10 khách mẫu (ổn định theo hash ID)

{md_table(sample_cols, sample_rows, 10)}
Chi tiết từng dòng fact để đối chiếu thủ công: `01b_customer_sample_fact_items.csv`.

## 2. Đối soát tổng (cần phân biệt revenue và GMV)

{md_table(metrics_cols, metrics_rows, 1)}
`mart.total_revenue` phải so với `SUM(fact.price)`; `mart.total_gmv` so với `SUM(fact.gmv)`.
Do `gmv = price + freight_value` nên cột `delta_revenue_vs_gmv_not_expected_zero` **không yêu cầu bằng 0**.

## 3. Phân phối RFM / K-Means

Cột hiện có: {', '.join(sorted(rfm_cols))}.
{'Không còn r_score, f_score, m_score, segment trong mart hiện tại. Phân phối cluster_id là phân khúc K-Means, không phải 5 segment RFM cũ.' if not {'r_score', 'f_score', 'm_score', 'segment'} <= rfm_cols else 'Đã xuất thêm bảng phân phối R/F/M score và segment.'}

{md_table(cluster_cols, cluster_rows)}

### Kiểm tra công thức RFM
{md_table(rfm_check_cols, rfm_check_rows, 1)}
- Recency = `date_diff('day', last_order_date, MAX(last_order_date))`; Frequency = `total_orders`; Monetary = `total_gmv`.

### Kiểm tra phân phối cụm so với dim_customer_cluster
{md_table(cluster_profile_cols, cluster_profile_rows)}
- Có {len(cluster_profile_mismatches)} cụm có tổng khách hoặc GMV khác với `dim_customer_cluster`. Nếu >0, kiểm tra thời điểm cập nhật profile/K-Means (không sửa số liệu nghiệm thu).

Các CSV: `03_rfm_frequency_distribution.csv`, `03_rfm_recency_distribution.csv`, `03_rfm_monetary_summary.csv` và `03_cluster_distribution.csv` (nếu có).

## 4. first_order_date: delivered so với all statuses

{md_table(first_summary_cols, first_summary_rows, 1)}
Ví dụ khác nhau (tối đa 20):

{md_table(first_cols, first_rows, 20)}
Đây là khác biệt định nghĩa, không tự động là lỗi dữ liệu.

## 5. Delivered nhưng delivered_date_key = -1

{md_table(missing_cols, missing_rows, 1)}
Đếm đơn bằng COUNT(DISTINCT order_id) vì fact_sales có grain từng order item.

## 6. Bằng chứng nghiệm thu

Chụp màn hình terminal lúc chạy script, đặc biệt dòng `[RESULT]`, và mở `02_global_reconciliation.csv` để chụp đủ 3 cột delta_gmv/delta_orders/delta_customers. Không dùng dữ liệu giả làm screenshot.
'''
(OUT / 'GD4.9_report.md').write_text(report, encoding='utf-8')
print('\n[RESULT]', 'PASS' if not failures else 'REVIEW / FAIL', 'failures:', failures)
print('[RFM]', rfm_summary)
print('[CLUSTER PROFILE REVIEW]', len(cluster_profile_mismatches), 'cluster(s) mismatch')
print('[REPORT]', OUT / 'GD4.9_report.md')
con.close()
sys.exit(0 if not failures else 2)
