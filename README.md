# Olist E-Commerce Data Warehouse

## 1. Giới thiệu Dự án
Dự án thực hiện chuyển đổi dữ liệu thô (OLTP) từ sàn thương mại điện tử Olist (Brazil) sang hệ thống kho dữ liệu phân tích đa chiều (OLAP). Mục tiêu là đánh giá hành vi mua hàng, hiệu suất giao hàng và giá trị vòng đời khách hàng (CLV) dựa trên tập dữ liệu gồm 9 bảng với hơn 99,000 đơn hàng.

## 2. Kiến trúc Hệ thống & Công nghệ
Hệ thống áp dụng **Medallion Architecture**, sử dụng **Python** làm Orchestrator và **DuckDB** làm Engine xử lý lõi:
*   **Data Ingestion:** Sử dụng Python & DuckDB đọc trực tiếp từ `data.xlsx` để tối ưu bộ nhớ.
*   **Data Transformation:** Sử dụng **dbt** (dbt-duckdb) để xây dựng luồng dữ liệu 3 tầng:
    *   **Tầng Bronze:** Lưu trữ nguyên bản 9 bảng dữ liệu.
    *   **Tầng Silver:** Làm sạch, chuẩn hóa kiểu dữ liệu, xử lý missing values và dịch thuật danh mục sản phẩm (Bồ Đào Nha -> Tiếng Anh).
    *   **Tầng Gold:** Mô hình Star Schema với các bảng `Dim_Customer`, `Dim_Product`, `Dim_Date`, `Dim_Location` và `Fact_Sales`, `Fact_Reviews`.
*   **Machine Learning:** Sử dụng `scikit-learn` (K-Means) để phân khúc khách hàng dựa trên chỉ số RFM (Recency, Frequency, Monetary).
*   **Data Visualization:** Xây dựng Dashboard CRM bằng **Streamlit** thể hiện doanh thu, bản đồ nhiệt địa lý (Sao Paulo, etc.) và phân bổ tệp khách hàng.

## 3. Hướng dẫn sử dụng
1. Clone repository này về máy.
2. Đặt file `data.xlsx` vào thư mục `data/raw/`.
3. Chạy lệnh cài đặt môi trường: `pip install -r requirements.txt`
4. Chạy script nạp dữ liệu: `python scripts/ingest_duckdb.py`
5. Khởi chạy luồng ETL với dbt: `cd dbt_olist && dbt run`
6. Xem Dashboard Streamlit: `streamlit run app/dashboard.py`