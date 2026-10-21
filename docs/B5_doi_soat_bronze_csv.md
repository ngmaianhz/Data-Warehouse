# BÁO CÁO MINH CHỨNG ĐỐI SOÁT DỮ LIỆU BRONZE VS CSV (GD3.5)

- **Dự án:** Olist E-Commerce Data Warehouse (Team 7)
- **Môi trường Data Warehouse:** DuckDB Local (C:\Users\Admin\Data-Warehouse\data\olist_warehouse.duckdb)
- **Thời gian thực hiện kiểm tra:** `2026-10-21 10:15:27`
- **Công cụ kiểm toán:** Python + DuckDB `information_schema.columns`

---

## 1. Yêu Cầu & Tiêu Chí Nghiệm Thu GD3.5
Với mỗi `_run_id` được nạp vào Data Warehouse:
1. **(1) Khớp số dòng:** `row_count_bronze == row_count_csv` (đếm trực tiếp từ file CSV nguồn đối chiếu với Bronze).
2. **(2) Khớp số cột:** `Số cột Bronze == Số cột CSV + 3` (3 cột metadata bắt buộc: `_load_timestamp`, `_source_file`, `_run_id`).
3. **(3) Đúng chuẩn kiểu Raw:** Toàn bộ cột dữ liệu gốc đều là `VARCHAR` (tra cứu qua `information_schema.columns`). Ba cột metadata có kiểu dữ liệu riêng (`_load_timestamp` là `TIMESTAMP`, `_source_file` là `VARCHAR`, `_run_id` là `VARCHAR`).
4. **Phạm vi kiểm thử:** Chưa đặt kiểm thử `UNIQUE` / `NOT NULL` tại tầng Bronze (các ràng buộc này được thiết lập tại tầng Silver qua dbt tests).

---

## 2. Bảng Đối Soát Chi Tiết 9 Bảng - Run ID: `20261021_101150_79ec90`

| STT | Tên bảng Bronze | File CSV nguồn | Dòng CSV | Dòng Bronze | Dòng khớp? | Cột CSV | Cột Bronze (Kỳ vọng) | Cột khớp? | Kiểu dữ liệu | Kết luận |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1 | `bronze_customers` | `olist_customers_dataset.csv` | 99,441 | 99,441 | PASS | 5 | 8 (8) | PASS | PASS (VARCHAR) | **PASS** |
| 2 | `bronze_geolocation` | `olist_geolocation_dataset.csv` | 1,000,163 | 1,000,163 | PASS | 5 | 8 (8) | PASS | PASS (VARCHAR) | **PASS** |
| 3 | `bronze_order_items` | `olist_order_items_dataset.csv` | 112,650 | 112,650 | PASS | 7 | 10 (10) | PASS | PASS (VARCHAR) | **PASS** |
| 4 | `bronze_order_payments` | `olist_order_payments_dataset.csv` | 103,886 | 103,886 | PASS | 5 | 8 (8) | PASS | PASS (VARCHAR) | **PASS** |
| 5 | `bronze_order_reviews` | `olist_order_reviews_dataset.csv` | 99,224 | 99,224 | PASS | 7 | 10 (10) | PASS | PASS (VARCHAR) | **PASS** |
| 6 | `bronze_orders` | `olist_orders_dataset.csv` | 99,441 | 99,441 | PASS | 8 | 11 (11) | PASS | PASS (VARCHAR) | **PASS** |
| 7 | `bronze_products` | `olist_products_dataset.csv` | 32,951 | 32,951 | PASS | 9 | 12 (12) | PASS | PASS (VARCHAR) | **PASS** |
| 8 | `bronze_sellers` | `olist_sellers_dataset.csv` | 3,095 | 3,095 | PASS | 4 | 7 (7) | PASS | PASS (VARCHAR) | **PASS** |
| 9 | `bronze_product_category_name_translation` | `product_category_name_translation.csv` | 71 | 71 | PASS | 2 | 5 (5) | PASS | PASS (VARCHAR) | **PASS** |

### Thống Kê Chi Tiết Kiểm Tra Schema Cột Gốc (Kiểu Raw):
| Tên bảng Bronze | Tổng số cột | Số cột gốc | Kiểu cột gốc | Cột Metadata & Kiểu | Kiểm tra Schema |
| :--- | :---: | :---: | :--- | :--- | :---: |
| `bronze_customers` | 8 | 5 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_geolocation` | 8 | 5 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_order_items` | 10 | 7 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_order_payments` | 8 | 5 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_order_reviews` | 10 | 7 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_orders` | 11 | 8 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_products` | 12 | 9 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_sellers` | 7 | 4 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_product_category_name_translation` | 5 | 2 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |

---

## 2. Bảng Đối Soát Chi Tiết 9 Bảng - Run ID: `20261021_101209_c4b7b6`

| STT | Tên bảng Bronze | File CSV nguồn | Dòng CSV | Dòng Bronze | Dòng khớp? | Cột CSV | Cột Bronze (Kỳ vọng) | Cột khớp? | Kiểu dữ liệu | Kết luận |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1 | `bronze_customers` | `olist_customers_dataset.csv` | 99,441 | 99,441 | PASS | 5 | 8 (8) | PASS | PASS (VARCHAR) | **PASS** |
| 2 | `bronze_geolocation` | `olist_geolocation_dataset.csv` | 1,000,163 | 1,000,163 | PASS | 5 | 8 (8) | PASS | PASS (VARCHAR) | **PASS** |
| 3 | `bronze_order_items` | `olist_order_items_dataset.csv` | 112,650 | 112,650 | PASS | 7 | 10 (10) | PASS | PASS (VARCHAR) | **PASS** |
| 4 | `bronze_order_payments` | `olist_order_payments_dataset.csv` | 103,886 | 103,886 | PASS | 5 | 8 (8) | PASS | PASS (VARCHAR) | **PASS** |
| 5 | `bronze_order_reviews` | `olist_order_reviews_dataset.csv` | 99,224 | 99,224 | PASS | 7 | 10 (10) | PASS | PASS (VARCHAR) | **PASS** |
| 6 | `bronze_orders` | `olist_orders_dataset.csv` | 99,441 | 99,441 | PASS | 8 | 11 (11) | PASS | PASS (VARCHAR) | **PASS** |
| 7 | `bronze_products` | `olist_products_dataset.csv` | 32,951 | 32,951 | PASS | 9 | 12 (12) | PASS | PASS (VARCHAR) | **PASS** |
| 8 | `bronze_sellers` | `olist_sellers_dataset.csv` | 3,095 | 3,095 | PASS | 4 | 7 (7) | PASS | PASS (VARCHAR) | **PASS** |
| 9 | `bronze_product_category_name_translation` | `product_category_name_translation.csv` | 71 | 71 | PASS | 2 | 5 (5) | PASS | PASS (VARCHAR) | **PASS** |

### Thống Kê Chi Tiết Kiểm Tra Schema Cột Gốc (Kiểu Raw):
| Tên bảng Bronze | Tổng số cột | Số cột gốc | Kiểu cột gốc | Cột Metadata & Kiểu | Kiểm tra Schema |
| :--- | :---: | :---: | :--- | :--- | :---: |
| `bronze_customers` | 8 | 5 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_geolocation` | 8 | 5 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_order_items` | 10 | 7 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_order_payments` | 8 | 5 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_order_reviews` | 10 | 7 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_orders` | 11 | 8 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_products` | 12 | 9 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_sellers` | 7 | 4 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |
| `bronze_product_category_name_translation` | 5 | 2 | 100% `VARCHAR` | `_load_timestamp` (TIMESTAMP), `_source_file` (VARCHAR), `_run_id` (VARCHAR) | **ĐẠT CHUẨN RAW** |

---

## 3. Giải Trình Thiết Kế & Quy Chuẩn Kiểm Thử Chất Lượng Dữ Liệu
### 3.1. Lý do toàn bộ cột gốc đều lưu trữ kiểu `VARCHAR` ở tầng Bronze
- **Bảo toàn dữ liệu nguồn tuyệt đối:** Các trường dữ liệu như mã bưu điện (`customer_zip_code_prefix`, `seller_zip_code_prefix`, `geolocation_zip_code_prefix`) có số `0` ở đầu (ví dụ `01046`). Nếu tự động ép kiểu `INTEGER` khi ingest sẽ bị mất số `0` dẫn đến sai lệch dữ liệu địa lý.
- **Không làm gián đoạn pipeline (Zero Ingestion Failure):** Dữ liệu thô trong thực tế thường chứa các ký tự lạ, lỗi định dạng ngày tháng, hoặc các giá trị ngoại lai. Việc giữ nguyên `VARCHAR` đảm bảo 100% bản ghi được nạp thành công vào Data Warehouse.
- **Truy vết nguồn gốc (Audit Trail):** Giữ nguyên giá trị gốc từ file CSV để đối soát khi phát hiện sai lệch ở các tầng phân tích cấp cao hơn.

### 3.2. Về việc chưa đặt test `UNIQUE` và `NOT NULL` tại Bronze
- **Phân định rõ trách nhiệm Medallion Architecture:** Tầng Bronze có nhiệm vụ duy nhất là **Raw Storage (Append-Only Ingestion)**. Tầng này phản ánh chính xác tình trạng thực tế của hệ thống nguồn (bao gồm cả dữ liệu trùng lặp hoặc thiếu sót nếu có).
- **Tầng Silver đảm nhiệm Data Cleansing & Data Quality Tests:** Toàn bộ các kiểm thử về tính toàn vẹn dữ liệu:
  - `unique` và `not_null` cho các khóa chính (ví dụ `order_id`, `customer_id`, `product_id`).
  - `accepted_values` cho các trạng thái đơn hàng (`delivered`, `shipped`...).
  - `relationships` kiểm tra khóa ngoại giữa các bảng.
  -> Đều được triển khai nghiêm ngặt tại tầng Silver thông qua dbt tests (`silver_orders.yml`, `silver_items_payments.yml`...).

---

## 4. Kết Luận Nghiệm Thu GD3.5
Hệ thống đã hoàn thành xuất sắc toàn bộ tiêu chí của **GD3.5 - Kiểm tra đối soát Bronze vs CSV**:
- [x] **100% số dòng khớp** giữa CSV và Bronze cho toàn bộ các đợt nạp (`_run_id`).
- [x] **100% số cột khớp chuẩn** (Số cột CSV + đúng 3 cột metadata hệ thống).
- [x] **100% cột nghiệp vụ gốc giữ nguyên định dạng VARCHAR** tra cứu minh bạch từ `information_schema.columns`.
- [x] Kiến trúc phân tầng rõ ràng: Giữ nguyên vẹn tầng Bronze và bàn giao toàn bộ kiểm thử nghiệp vụ cho tầng Silver.