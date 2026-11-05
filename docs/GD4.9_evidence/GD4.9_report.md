# GD4.9 — Kiểm chứng & đối soát (kết quả truy vấn thực tế)

- Database: MotherDuck `olist_warehouse`; chạy lúc: 2026-11-05T18:40:17+07:00.
- Chỉ chạy SELECT, không cập nhật dữ liệu. Bảng thực tế: `"main_gold"."fact_sales"`, `"main_mart"."mart_customer_360"`, `"main_mart"."mart_customer_rfm"`, `"main_gold"."dim_customer"`.
- Kết quả tự động: **PASS**. Kiểm tra: tất cả sai lệch kỳ vọng 0 đều bằng 0.

## 1. Đối soát 10 khách mẫu (ổn định theo hash ID)

| customer_unique_id | fact_revenue | mart_revenue | revenue_delta | fact_gmv | mart_gmv | gmv_delta | fact_orders | mart_orders | orders_delta |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 21747a07d23ec1345b45e27298d556aa | 69.99 | 69.99 | 0.00 | 87.22 | 87.22 | 0.00 | 1 | 1 | 0 |
| 243a60e496c1f5289946e9cea1b0987a | 58.90 | 58.90 | 0.00 | 77.41 | 77.41 | 0.00 | 1 | 1 | 0 |
| 30a276fc3eacdbb80f28e6164005db8f | 49.90 | 49.90 | 0.00 | 72.75 | 72.75 | 0.00 | 1 | 1 | 0 |
| 383e742502eccf91e90662929acf9364 | 21.99 | 21.99 | 0.00 | 36.09 | 36.09 | 0.00 | 1 | 1 | 0 |
| 538635116fdea3c0b90ee91e9e64ceb0 | 59.99 | 59.99 | 0.00 | 72.66 | 72.66 | 0.00 | 1 | 1 | 0 |
| 7b4f035053061c550b12aaaba3ee88e1 | 64.90 | 64.90 | 0.00 | 80.10 | 80.10 | 0.00 | 1 | 1 | 0 |
| 85475e754525d6d222d917dbc8251801 | 2399.00 | 2399.00 | 0.00 | 2438.51 | 2438.51 | 0.00 | 1 | 1 | 0 |
| bff4f9bb1e3210cbd8526dffbd87dc58 | 179.98 | 179.98 | 0.00 | 296.86 | 296.86 | 0.00 | 1 | 1 | 0 |
| e16c17b4f6833c2126de803d3f94bd87 | 47.98 | 47.98 | 0.00 | 63.54 | 63.54 | 0.00 | 1 | 1 | 0 |
| e24fd88c2ae70a0eac18426e9485afe1 | 55.00 | 55.00 | 0.00 | 92.30 | 92.30 | 0.00 | 1 | 1 | 0 |

Chi tiết từng dòng fact để đối chiếu thủ công: `01b_customer_sample_fact_items.csv`.

## 2. Đối soát tổng (cần phân biệt revenue và GMV)

| fact_revenue | fact_gmv | fact_orders | fact_customers | orders_missing_customer | mart_revenue | mart_gmv | mart_orders | mart_customers | mart_distinct_customers | delta_revenue_correct | delta_gmv | delta_orders | delta_customers | delta_duplicate_mart_customers | delta_revenue_vs_gmv_not_expected_zero |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 13221498.11 | 15419773.75 | 96478 | 93358 | 0 | 13221498.11 | 15419773.75 | 96478 | 93358 | 93358 | 0.00 | 0.00 | 0 | 0 | 0 | -2198275.64 |

`mart.total_revenue` phải so với `SUM(fact.price)`; `mart.total_gmv` so với `SUM(fact.gmv)`.
Do `gmv = price + freight_value` nên cột `delta_revenue_vs_gmv_not_expected_zero` **không yêu cầu bằng 0**.

## 3. Phân phối RFM / K-Means

Cột hiện có: cluster_id, customer_unique_id, dbt_created_at, frequency, monetary, recency_days.
Không còn r_score, f_score, m_score, segment trong mart hiện tại. Phân phối cluster_id là phân khúc K-Means, không phải 5 segment RFM cũ.

| cluster_id | customer_count | pct |
| --- | --- | --- |
| 1 | 2801 | 3.0 |
| 2 | 27585 | 29.55 |
| 3 | 27014 | 28.94 |
| 4 | 35958 | 38.52 |


### Kiểm tra công thức RFM
| customer_360_count | rfm_row_count | rfm_unique_count | missing_rfm | wrong_recency | wrong_frequency | wrong_monetary |
| --- | --- | --- | --- | --- | --- | --- |
| 93358 | 93358 | 93358 | 0 | 0 | 0 | 0 |

- Recency = `date_diff('day', last_order_date, MAX(last_order_date))`; Frequency = `total_orders`; Monetary = `total_gmv`.

### Kiểm tra phân phối cụm so với dim_customer_cluster
| cluster_id | cluster_label | observed_customers | profile_customers | delta_customers | observed_monetary | sum_monetary | delta_monetary |
| --- | --- | --- | --- | --- | --- | --- | --- |
| -1 | Chưa phân cụm | 0 | 0 | 0 | NULL | 0.00 | 0.00 |
| 1 | C1 · Mua lặp | 2801 | 2801 | 0 | 864187.46 | 864187.46 | 0.00 |
| 2 | C2 · Mới mua · chi cao | 27585 | 27585 | 0 | 8855497.14 | 8855497.14 | 0.00 |
| 3 | C3 · Lâu chưa mua · chi thấp | 27014 | 27014 | 0 | 3188980.29 | 3188980.29 | 0.00 |
| 4 | C4 · Mới mua · chi thấp | 35958 | 35958 | 0 | 2511108.86 | 2511108.86 | 0.00 |

- Có 0 cụm có tổng khách hoặc GMV khác với `dim_customer_cluster`. Nếu >0, kiểm tra thời điểm cập nhật profile/K-Means (không sửa số liệu nghiệm thu).

Các CSV: `03_rfm_frequency_distribution.csv`, `03_rfm_recency_distribution.csv`, `03_rfm_monetary_summary.csv` và `03_cluster_distribution.csv` (nếu có).

## 4. first_order_date: delivered so với all statuses

| customers_in_mart | missing_in_dim | equal_dates | mart_later | mart_earlier | dim_null_dates |
| --- | --- | --- | --- | --- | --- |
| 93358 | 0 | 93291 | 67 | 0 | 0 |

Ví dụ khác nhau (tối đa 20):

| customer_unique_id | first_delivered_purchase_date | first_any_status_purchase_date | date_gap_days |
| --- | --- | --- | --- |
| 5eefb861d4921a3e628bbc65c50a480a | 2018-08-05 | 2017-03-05 | 518 |
| 30b782a79466007756f170cb5bd6bbd8 | 2018-07-14 | 2017-02-20 | 509 |
| 7f5dcde4d292354dd5e6968a27971126 | 2018-08-14 | 2017-04-08 | 493 |
| 8cfc5350efe3bce6a0d6f96fbaf2c3b4 | 2018-08-05 | 2017-05-14 | 448 |
| f019bdb8008924769fe88319cddedda9 | 2018-02-28 | 2017-02-12 | 381 |
| efd22f5f8fc7e5035a4f48bd92c0c69c | 2018-03-27 | 2017-03-25 | 367 |
| 3c5e1130694632f44051b23fd86ad9e2 | 2018-04-16 | 2017-04-27 | 354 |
| 952bdd2866ddfc528203799b6b7a24e1 | 2018-04-19 | 2017-06-11 | 312 |
| ac3dcee918e6c96eb2ab467158143697 | 2018-05-04 | 2017-07-25 | 283 |
| e4d18909afd252a0289765acc614d3e0 | 2018-07-09 | 2017-09-29 | 283 |
| 91687e2315fd578c976f37533a7d597a | 2017-11-25 | 2017-02-16 | 282 |
| 6eb453dca2505def092eb261e3a3d8d0 | 2018-03-29 | 2017-06-23 | 279 |
| 004b45ec5c64187465168251cd1c9c2f | 2018-05-26 | 2017-09-01 | 267 |
| 934e91b0e98dbbeb3649cb1091cca051 | 2017-11-22 | 2017-03-04 | 263 |
| e4951b10e341a56871ef584deab3f2ef | 2018-08-25 | 2017-12-10 | 258 |
| accd68fd87adda3d6360d77daafd964d | 2018-08-04 | 2017-12-04 | 243 |
| 10d5890ed5e7ec78a7db23b5ac579b17 | 2018-07-23 | 2017-12-05 | 230 |
| 5192c897072033288df55bd01b0e5737 | 2018-07-22 | 2017-12-04 | 230 |
| 61181b9bc9188678b5991d89064dd961 | 2017-10-11 | 2017-02-24 | 229 |
| c27a30338b5d9d59399825f77e7dcc61 | 2018-06-11 | 2017-11-11 | 212 |

Đây là khác biệt định nghĩa, không tự động là lỗi dữ liệu.

## 5. Delivered nhưng delivered_date_key = -1

| delivered_orders_with_date_key_minus_1 | fact_item_rows_with_date_key_minus_1 |
| --- | --- |
| 8 | 8 |

Đếm đơn bằng COUNT(DISTINCT order_id) vì fact_sales có grain từng order item.

## 6. Bằng chứng nghiệm thu

[RESULT] PASS failures: []
[RFM] {'customer_360_count': 93358, 'rfm_row_count': 93358, 'rfm_unique_count': 93358, 'missing_rfm': 0, 'wrong_recency': 0, 'wrong_frequency': 0, 'wrong_monetary': 0}
[CLUSTER PROFILE REVIEW] 0 cluster(s) mismatch
