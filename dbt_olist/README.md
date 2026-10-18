# DỰ ÁN DBT CORE CHO KHO DỮ LIỆU OLIST (TEAM 7)

Dự án này sử dụng **dbt Core** kết hợp adapter **`dbt-duckdb`** để thực hiện quá trình chuyển đổi dữ liệu (Transformation) theo kiến trúc phân tầng **Medallion (Bronze $\rightarrow$ Silver $\rightarrow$ Gold)** và kết nối trực tiếp với Cloud Data Warehouse **MotherDuck** (`md:olist_warehouse`).

---

## 1. Cấu Trúc Thư Mục Dự Án

```
dbt_olist/
├── dbt_project.yml          # Cấu hình chính của dự án dbt, profile mapping và materialization
├── profiles.yml             # Cấu hình kết nối MotherDuck (đọc token an toàn qua env_var)
├── packages.yml             # Khai báo các dbt package phụ thuộc (dbt-utils)
├── package-lock.yml         # Khóa phiên bản các package đã tải
├── dbt_packages/            # Mã nguồn các package (đã được cấu hình trong .gitignore)
├── models/
│   ├── bronze/
│   │   └── sources.yml      # Khai báo 9 bảng dữ liệu thô (Raw/Bronze) kèm loaded_at_field
│   ├── silver/              # Các model làm sạch, chuẩn hóa, ép kiểu dữ liệu
│   └── gold/                # Các bảng Fact & Dimension theo mô hình Kimball Star Schema
├── macros/                  # Macro SQL tùy biến
├── analyses/                # Các truy vấn phân tích ad-hoc
├── tests/                   # Các kiểm thử singular tests nâng cao
└── README.md                # Tài liệu hướng dẫn này
```

---

## 2. Tiêu Chuẩn Bảo Mật (Security & Credentials)

- **Không lưu Token cứng trong mã nguồn:** File `profiles.yml` được cấu hình sử dụng hàm Jinja `{{ env_var('MOTHERDUCK_TOKEN') }}`.
- **Biến môi trường:** Token được lưu tại file `.env` ở thư mục gốc của repository (đã nằm trong `.gitignore`).
- **An toàn khi Push Git:** Các thành viên trong nhóm có thể commit và push toàn bộ thư mục `dbt_olist` lên GitHub mà không sợ bị lộ Access Token của MotherDuck.

---

## 3. Danh Sách 9 Bảng Bronze (Nguồn Dữ Liệu Thô)

Tất cả 9 bảng dữ liệu thô được định nghĩa trong `models/bronze/sources.yml` kèm trường kiểm soát thời gian nạp `loaded_at_field: _load_timestamp`:

1. `olist_customers_dataset`: Thông tin định danh và địa chỉ khách hàng.
2. `olist_geolocation_dataset`: Tọa độ địa lý (vĩ độ, kinh độ, thành phố, bang) theo zip code.
3. `olist_order_items_dataset`: Chi tiết từng sản phẩm trong đơn hàng, giá bán, phí vận chuyển.
4. `olist_order_payments_dataset`: Phương thức thanh toán, số tiền và số kỳ trả góp.
5. `olist_order_reviews_dataset`: Đánh giá của khách hàng, điểm sao và nhận xét.
6. `olist_orders_dataset`: Tổng quan đơn hàng, trạng thái và mốc thời gian xử lý.
7. `olist_products_dataset`: Danh mục sản phẩm, kích thước và khối lượng.
8. `olist_sellers_dataset`: Thông tin định danh và địa chỉ người bán hàng.
9. `product_category_name_translation`: Bảng dịch tên ngành hàng từ tiếng Bồ Đào Nha sang tiếng Anh.

---

## 4. Hướng Dẫn Vận Hành Cho Thành Viên Nhóm

### Cách 1: Sử dụng Runner Python tích hợp sẵn (Khuyên dùng)
Tại thư mục gốc `Data-Warehouse`, chạy bằng launcher `py`:

- **Kiểm tra kết nối tới MotherDuck:**
  ```powershell
  py scripts/run_dbt.py debug
  ```
- **Cài đặt / Cập nhật dbt packages (`dbt_utils`):**
  ```powershell
  py scripts/run_dbt.py deps
  ```
- **Kiểm tra cú pháp và danh sách sources:**
  ```powershell
  py scripts/run_dbt.py ls --resource-type source
  ```
- **Biên dịch và chạy các models (sau khi tạo model):**
  ```powershell
  py scripts/run_dbt.py run
  ```
- **Chạy kiểm thử chất lượng dữ liệu:**
  ```powershell
  py scripts/run_dbt.py test
  ```

### Cách 2: Chạy trực tiếp lệnh `dbt` qua Terminal
Nếu đã thêm Python Scripts vào PATH hoặc kích hoạt virtual environment:
```powershell
# Di chuyển vào thư mục dbt_olist
cd dbt_olist

# Chạy dbt với thư mục profile hiện tại
dbt debug --profiles-dir .
dbt deps --profiles-dir .
```

---

## 5. Kết Quả Kiểm Thử (Verification Status)
- `dbt debug`: **All checks passed!** (Kết nối tới `md:olist_warehouse` trạng thái OK).
- `dbt deps`: Cài đặt thành công `dbt-labs/dbt_utils` phiên bản **1.4.1**.
- `dbt ls`: Nhận diện đầy đủ 9 bảng nguồn tại `source:dbt_olist.bronze.*`.
