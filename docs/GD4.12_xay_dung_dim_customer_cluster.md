# BÁO CÁO NGHIỆM THU NHIỆM VỤ GD4.12: XÂY DỰNG BẢNG CHIỀU PHÂN CỤM KHÁCH HÀNG (dim_customer_cluster)

- **Mã nhiệm vụ (Task ID):** GD4.12
- **Dự án:** Olist E-Commerce Data Warehouse (Team 7)
- **Tầng dữ liệu:** Data Mart (Gold / Semantic Layer)
- **Thời điểm hoàn thành:** 2026-11-03 13:40:00
- **Môi trường triển khai:** MotherDuck Cloud Data Warehouse (`md:olist_warehouse`)
- **Công cụ chuyển đổi & kiểm thử:** dbt Core (v1.12.6) + `dbt-duckdb` + DuckDB v1.5.6

---

## 1. Tổng Quan Nhiệm Vụ & Căn Cứ Thiết Kế

### 1.1. Bối cảnh & Căn cứ thiết kế
Căn cứ theo tài liệu đặc tả kiến trúc **`[DW] GD4.1 Customer Data Mart Design.pdf`** (Mục 3.2 và Sơ đồ Data Mart trang 11), bảng chiều phân cụm khách hàng `dim_customer_cluster` đóng vai trò là bảng danh mục chuẩn mực (Master/Dimension Table) lưu trữ toàn bộ thông tin định danh, nhãn phân loại nghiệp vụ, mô tả hành vi và chân dung định lượng của từng cụm khách hàng được hình thành từ mô hình phân cụm K-Means ($K=3$) trong pipeline Machine Learning (`notebooks/04_ml_clustering.ipynb`).

```
                    ┌────────────────────────┐
                    │  dim_customer_cluster  │ (Grain: 1 dòng / cluster_id)
                    ├────────────────────────┤
                    │ PK cluster_id (INT)    │
                    │    cluster_label       │
                    │    cluster_description │
                    │    (profile metrics...)│
                    └───────────┬────────────┘
                                │ 1
                                │
                                │ *
                    ┌───────────┴────────────┐
                    │   mart_customer_rfm /  │
                    │    mart_customer_360   │
                    └────────────────────────┘
```

### 1.2. Mục tiêu kỹ thuật
1. **Chuẩn hóa Grain & Khóa chính:** Tuyên bố mức độ hạt chuẩn mực: **1 dòng đại diện cho 1 cụm phân khúc khách hàng** (`1 row per cluster_id`). Khóa chính là `cluster_id` (INTEGER).
2. **Quản lý tập trung Metadata phân cụm:** Đảm bảo toàn bộ các bảng hạ nguồn (như `mart_customer_rfm`, `mart_customer_360`, BI Dashboard) chỉ cần lưu trữ `cluster_id` làm khóa ngoại (FK), qua đó giảm thiểu dư thừa dữ liệu (Data Redundancy) và tránh lỗi bất nhất khi cập nhật định nghĩa cụm.
3. **Bảo toàn tính toàn vẹn tham chiếu (Referential Integrity):** Bổ sung bản ghi giả lập **Sentinel Record (`cluster_id = -1`)** theo phương pháp luận Kimball nhằm đại diện cho các khách hàng chưa đủ điều kiện phân cụm (ví dụ: đơn hàng chưa hoàn tất giao dịch `delivered`) hoặc khách hàng mới phát sinh chưa chạy qua chu kỳ retrain mô hình ML.
4. **Cô lập kiến trúc (Zero Pipeline Dependency Race Condition):** Mô hình hóa thông qua CTE định nghĩa tĩnh kết quả tối ưu từ `ml.cluster_profile` đã được huấn luyện, giúp quy trình `dbt build` chạy độc lập, tái lập 100% (deterministic), không bị phụ thuộc vòng hoặc xung đột thứ tự build với notebook phân tích Python/PySpark.

---

## 2. Đặc Tả Từ Điển Dữ Liệu (Data Dictionary)

Bảng được cấu hình materialization dạng `table` tại schema `main_mart` trên MotherDuck Cloud (`olist_warehouse.main_mart.dim_customer_cluster`):

| STT | Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Ý Nghĩa Nghiệp Vụ / Công Thức Tính |
| :---: | :--- | :---: | :---: | :--- |
| 1 | `cluster_id` | `INTEGER` | **PK**, NOT NULL, UNIQUE | Mã định danh duy nhất của cụm (1, 2, 3 và -1) |
| 2 | `cluster_label` | `VARCHAR` | NOT NULL, UNIQUE | Nhãn định danh ngắn gọn đặc trưng cụm |
| 3 | `cluster_description` | `VARCHAR` | NOT NULL | Mô tả chi tiết hành vi, trải nghiệm và giá trị đóng góp của cụm |
| 4 | `n_customers` | `INTEGER` | NOT NULL | Số lượng khách hàng được phân bổ vào cụm |
| 5 | `pct_customers` | `DECIMAL(4,2)` | NOT NULL | Tỷ lệ phần trăm khách hàng của cụm trên toàn sàn (%) |
| 6 | `sum_gmv` | `DECIMAL(9,2)` | NOT NULL | Tổng giá trị hàng hóa (GMV) mà cụm đóng góp (BRL) |
| 7 | `pct_gmv` | `DECIMAL(4,2)` | NOT NULL | Tỷ trọng phần trăm GMV của cụm trên toàn bộ doanh thu sàn (%) |
| 8 | `median_recency_days` | `DECIMAL(4,1)` | NULL (cho -1) | Trung vị số ngày kể từ lần mua gần nhất đến mốc phân tích (ngày) |
| 9 | `median_total_gmv` | `DECIMAL(5,2)` | NULL (cho -1) | Trung vị giá trị chi tiêu GMV tích lũy của khách hàng (BRL) |
| 10 | `mean_total_gmv` | `DECIMAL(5,2)` | NULL (cho -1) | Giá trị chi tiêu GMV trung bình của khách hàng (BRL) |
| 11 | `avg_review_score` | `DECIMAL(3,2)` | NULL (cho -1) | Điểm đánh giá trải nghiệm dịch vụ trung bình (thang 1 - 5 sao) |
| 12 | `median_lead_time_days` | `DECIMAL(3,1)` | NULL (cho -1) | Thời gian giao hàng thực tế trung vị (ngày) |
| 13 | `late_order_rate` | `DECIMAL(5,4)` | NULL (cho -1) | Tỷ lệ đơn hàng bị giao trễ so với ngày dự kiến giao hàng |
| 14 | `top_state` | `VARCHAR` | NOT NULL | Bang có mật độ khách hàng tập trung cao nhất (ví dụ: SP) |
| 15 | `dbt_created_at` | `TIMESTAMP_TZ` | NOT NULL | Dấu thời gian dbt thực thi khởi tạo/cập nhật bản ghi |

---

## 3. Chân Dung Chi Tiết Các Cụm Khách Hàng (K-Means K=3 & Sentinel -1)

Căn cứ vào mô hình K-Means tối ưu đạt Silhouette Score cao nhất trên không gian đặc trưng RFM + Trải nghiệm vận chuyển trong `notebooks/04_ml_clustering.ipynb`, dữ liệu trong `dim_customer_cluster` được định hình như sau:

| `cluster_id` | `cluster_label` | Số KH (`n_customers`) | Tỷ lệ KH (`pct_customers`) | Tổng GMV (`sum_gmv`) | Tỷ lệ GMV (`pct_gmv`) | Median Recency | Median GMV | Điểm Review TB | Tỷ lệ giao trễ |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **-1** | **Chưa phân cụm (Unassigned)** | 0 | 0.00% | 0.00 BRL | 0.00% | *NULL* | *NULL* | *NULL* | *NULL* |
| **1** | **C1 · Lâu rồi · Chi cao · Không hài lòng** | 15,523 | 16.63% | 3,067,611.60 BRL | 19.89% | 218.0 ngày | 125.87 BRL | **1.94 sao** | **38.65%** |
| **2** | **C2 · Lâu rồi · Chi thấp · Hài lòng** | 56,690 | 60.72% | 9,248,487.09 BRL | 59.98% | 278.0 ngày | 107.02 BRL | **4.63 sao** | **1.76%** |
| **3** | **C3 · Gần đây · Chi thấp · Hài lòng** | 21,145 | 22.65% | 3,103,675.06 BRL | 20.13% | 54.0 ngày | 97.43 BRL | **4.51 sao** | **2.81%** |

### Đặc điểm định tính & Hành động nghiệp vụ:
1. **Cụm 1 (`cluster_id = 1`): Nhóm Khách Hàng Chi Tiêu Cao Có Nguy Cơ Rời Bỏ Do Giao Vận (High-Value At-Risk):**
   - **Đặc trưng:** Mức chi tiêu trung bình cao nhất sàn (mean 197.62 BRL, median 125.87 BRL), đóng góp xấp xỉ 20% doanh số. Tuy nhiên, thời gian giao hàng kéo dài trung vị 21 ngày và có đến 38.65% đơn hàng bị trễ hạn, dẫn đến điểm CSAT tụt dốc thảm hại (1.94/5 sao).
   - **Hành động đề xuất:** Cần gửi thông điệp xin lỗi kèm voucher đền bù, ưu tiên nâng cấp đối tác logistics và luồng chăm sóc khách hàng VIP để ngăn ngừa rời bỏ vĩnh viễn.
2. **Cụm 2 (`cluster_id = 2`): Nhóm Khách Hàng Đại Chúng Hài Lòng Nhưng Ngủ Đông (Dormant Satisfied Mass):**
   - **Đặc trưng:** Chiếm tới 60.72% tệp khách hàng và 59.98% tổng doanh số sàn. Dù đã lâu chưa quay lại mua sắm (median Recency 278 ngày), nhóm này có ấn tượng rất tốt về dịch vụ (review 4.63 sao, giao sớm 14.15 ngày, trễ chỉ 1.76%).
   - **Hành động đề xuất:** Triển khai các chiến dịch Win-Back (tái kích hoạt) thông qua email gợi ý sản phẩm theo mùa, flash sale dành cho khách hàng thân thiết.
3. **Cụm 3 (`cluster_id = 3`): Nhóm Khách Hàng Mới Tích Cực (Recent Satisfied Adopters):**
   - **Đặc trưng:** Mua sắm gần đây (median Recency chỉ 54 ngày), dịch vụ giao hàng cực nhanh (lead time trung vị 6 ngày, giao sớm 12.75 ngày, trễ chỉ 2.81%), đánh giá hài lòng xuất sắc (4.51 sao).
   - **Hành động đề xuất:** Thực hiện chiến dịch Cross-sell/Up-sell để nuôi dưỡng trở thành khách hàng trung thành giá trị cao.
4. **Cụm -1 (`cluster_id = -1`): Bản Ghi Giả Lập Sentinel:**
   - **Mục đích:** Bảo vệ toàn vẹn tham chiếu khóa ngoại cho toàn bộ các bản ghi khách hàng chưa đủ điều kiện phân cụm, đảm bảo câu lệnh `JOIN` giữa Mart và Dimension không bao giờ làm rơi rụng bản ghi hoặc sinh ra `NULL`.

---

## 4. Kết Quả Thực Thi dbt Build & Kiểm Định Chất Lượng (11/11 PASS)

Mô hình `dim_customer_cluster` đã được biên dịch, build thành công dưới dạng bảng thực trên MotherDuck và vượt qua toàn bộ **10 bài kiểm thử hợp đồng dữ liệu**:

```
[*] Thực thi dbt với tham số: build --select dim_customer_cluster
06:37:15  Running with dbt=1.12.6
06:37:15  Registered adapter: duckdb=1.11.0
06:37:17  Found 24 models, 280 data tests, 15 sources, 616 macros
06:37:17  Concurrency: 4 threads (target='dev')
06:37:27  1 of 11 START sql table model main_mart.dim_customer_cluster ................... [RUN]
06:37:29  1 of 11 OK created sql table model main_mart.dim_customer_cluster .............. [OK in 1.98s]
06:37:29  2 of 11 START test not_null_dim_customer_cluster_cluster_description ........... [RUN]
06:37:29  3 of 11 START test not_null_dim_customer_cluster_cluster_id .................... [RUN]
06:37:29  4 of 11 START test not_null_dim_customer_cluster_cluster_label ................. [RUN]
06:37:29  5 of 11 START test not_null_dim_customer_cluster_dbt_created_at ................ [RUN]
06:37:29  5 of 11 PASS not_null_dim_customer_cluster_dbt_created_at ...................... [PASS in 0.36s]
06:37:29  6 of 11 START test not_null_dim_customer_cluster_n_customers ................... [RUN]
06:37:29  2 of 11 PASS not_null_dim_customer_cluster_cluster_description ................. [PASS in 0.43s]
06:37:29  3 of 11 PASS not_null_dim_customer_cluster_cluster_id .......................... [PASS in 0.43s]
06:37:29  4 of 11 PASS not_null_dim_customer_cluster_cluster_label ....................... [PASS in 0.43s]
06:37:29  7 of 11 START test not_null_dim_customer_cluster_pct_customers ................. [RUN]
06:37:29  8 of 11 START test not_null_dim_customer_cluster_pct_gmv ....................... [RUN]
06:37:29  9 of 11 START test not_null_dim_customer_cluster_sum_gmv ....................... [RUN]
06:37:30  6 of 11 PASS not_null_dim_customer_cluster_n_customers ......................... [PASS in 0.32s]
06:37:30  10 of 11 START test unique_dim_customer_cluster_cluster_id ..................... [RUN]
06:37:30  7 of 11 PASS not_null_dim_customer_cluster_pct_customers ....................... [PASS in 0.42s]
06:37:30  9 of 11 PASS not_null_dim_customer_cluster_sum_gmv ............................. [PASS in 0.41s]
06:37:30  8 of 11 PASS not_null_dim_customer_cluster_pct_gmv ............................. [PASS in 0.42s]
06:37:30  11 of 11 START test unique_dim_customer_cluster_cluster_label .................. [RUN]
06:37:30  10 of 11 PASS unique_dim_customer_cluster_cluster_id ........................... [PASS in 0.28s]
06:37:30  11 of 11 PASS unique_dim_customer_cluster_cluster_label ........................ [PASS in 0.31s]
06:37:30  Finished running 1 table model, 10 data tests in 0 hours 0 minutes and 13.01 seconds (13.01s).
06:37:30  Completed successfully
06:37:30  Done. PASS=11 WARN=0 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=11
```

### Bảng chi tiết kết quả kiểm định:
| STT | Tên Test | Loại Kiểm Thử | Trường Kiểm Thử | Trạng Thái | Thời Gian |
| :---: | :--- | :--- | :--- | :---: | :---: |
| 1 | `unique_dim_customer_cluster_cluster_id` | Uniqueness (Tính duy nhất PK) | `cluster_id` | **PASS** | 0.28s |
| 2 | `not_null_dim_customer_cluster_cluster_id` | Completeness (Không rỗng PK) | `cluster_id` | **PASS** | 0.43s |
| 3 | `unique_dim_customer_cluster_cluster_label` | Business Rule (Nhãn cụm không trùng) | `cluster_label` | **PASS** | 0.31s |
| 4 | `not_null_dim_customer_cluster_cluster_label` | Completeness | `cluster_label` | **PASS** | 0.43s |
| 5 | `not_null_dim_customer_cluster_cluster_description` | Completeness | `cluster_description` | **PASS** | 0.43s |
| 6 | `not_null_dim_customer_cluster_n_customers` | Completeness | `n_customers` | **PASS** | 0.32s |
| 7 | `not_null_dim_customer_cluster_pct_customers` | Completeness | `pct_customers` | **PASS** | 0.42s |
| 8 | `not_null_dim_customer_cluster_sum_gmv` | Completeness | `sum_gmv` | **PASS** | 0.41s |
| 9 | `not_null_dim_customer_cluster_pct_gmv` | Completeness | `pct_gmv` | **PASS** | 0.42s |
| 10 | `not_null_dim_customer_cluster_dbt_created_at` | Completeness | `dbt_created_at` | **PASS** | 0.36s |

---

## 5. Truy Vấn Trực Tiếp Trên MotherDuck

Dữ liệu thực tế được truy vấn trực tiếp từ Cloud Data Warehouse (`olist_warehouse.main_mart.dim_customer_cluster`):

```sql
SELECT 
    cluster_id, 
    cluster_label, 
    n_customers, 
    pct_customers, 
    sum_gmv, 
    pct_gmv, 
    median_recency_days, 
    median_total_gmv, 
    avg_review_score, 
    late_order_rate, 
    top_state 
FROM olist_warehouse.main_mart.dim_customer_cluster 
ORDER BY cluster_id;
```

**Kết quả trả về:**
```text
   cluster_id                            cluster_label  n_customers  pct_customers     sum_gmv  pct_gmv  median_recency_days  median_total_gmv  avg_review_score  late_order_rate top_state
0          -1               Chưa phân cụm (Unassigned)            0           0.00        0.00     0.00                  NaN               NaN               NaN              NaN       N/A
1           1  C1 · Lâu rồi · Chi cao · Không hài lòng        15523          16.63  3067611.60    19.89                218.0            125.87              1.94           0.3865        SP
2           2       C2 · Lâu rồi · Chi thấp · Hài lòng        56690          60.72  9248487.09    59.98                278.0            107.02              4.63           0.0176        SP
3           3       C3 · Gần đây · Chi thấp · Hài lòng        21145          22.65  3103675.06    20.13                 54.0             97.43              4.51           0.0281        SP
```

---

## 6. Tổng Kết Danh Mục Tệp Bàn Giao

Các thành phần kỹ thuật đã được tạo và đồng bộ trong repository:
1. **Model SQL:** [`dbt_olist/models/mart/dim_customer_cluster.sql`](../dbt_olist/models/mart/dim_customer_cluster.sql)
2. **Data Contract & Tests:** Khai báo cấu trúc và 10 data tests trong [`dbt_olist/models/mart/schema.yml`](../dbt_olist/models/mart/schema.yml).
3. **Báo cáo nghiệm thu kỹ thuật:** [`docs/GD4.12_xay_dung_dim_customer_cluster.md`](GD4.12_xay_dung_dim_customer_cluster.md).
4. **Bảng thực thể:** `olist_warehouse.main_mart.dim_customer_cluster` đã được materialized dưới dạng bảng vật lý trên MotherDuck Cloud, sẵn sàng phục vụ các báo cáo BI và phân tích hạ nguồn.

