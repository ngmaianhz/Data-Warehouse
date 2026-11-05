# GD5.1 · Olist CRM Dashboard (Streamlit)

Tầng Application trong kiến trúc nhóm: đọc trực tiếp **Core DW** (`main_gold`, Star Schema) và **Customer Data Mart**
(`main_mart`, gồm kết quả K-Means ghi ngược về Mart) trên MotherDuck. Không đọc Bronze/Silver.

## Chạy
```powershell
venv\Scripts\activate
python -m pip install -r app/requirements.txt
copy .streamlit\secrets.toml.example .streamlit\secrets.toml   # rồi dán MOTHERDUCK_TOKEN (file này đã gitignore)
streamlit run app/01_app_dashboard.py
```
Nếu không tạo secrets.toml, app tự đọc `MOTHERDUCK_TOKEN` từ file `.env` ở gốc repo.

## Cấu trúc
| File | Nội dung | Bảng nguồn |
|---|---|---|
| `01_app_dashboard.py` | Điều hướng (st.navigation) | — |
| `views/0_Overview.py` | Dải kiến trúc, 6 KPI (so cùng kỳ), xu hướng tháng, top bang, cụm K-Means, observability | fact_sales, fact_customer_reviews, mart_*, dim_customer_cluster, obs_pipeline_health |
| `views/1_BOD.py` | MoM, quý, so sánh năm, Pareto bang, ngày trong tuần | fact_sales, dim_date |
| `views/2_Marketing.py` | Hồ sơ 4 cụm, R×M, recency, cụm×bang, giao trễ×cụm, khách mới, số đơn/khách, thanh toán | dim_customer_cluster, mart_customer_rfm, mart_customer_360, dim_payment_type |
| `views/3_Sales.py` | Top ngành, xu hướng ngành, CSAT ngành (trọng số 1/k), Pareto seller, bang seller | fact_sales, dim_product, dim_seller, fact_customer_reviews |
| `views/4_Logistics.py` | Lead time, theo bang, ma trận tuyến, review theo nhóm lead time | fact_sales, dim_date, dim_seller, fact_customer_reviews, mart_customer_360 |
| `db.py` | Kết nối (cache_resource), query có tham số `?` (cache_data 1 giờ), bộ lọc dùng chung | — |
| `ui.py` | Theme, header + bộ lọc, thẻ KPI, ô biểu đồ, menu tải CSV | — |

## Thiết kế
- Mỗi trang vừa **1 màn hình ngang 16:9**: header (logo, bộ lọc tháng/bang + bộ lọc riêng của trang), hàng thẻ KPI, 2 hàng ô biểu đồ.
- Dashboard **không ghi sẵn nhận định**: là cầu nối để nhà quản trị / DA tự đọc số và rút ra insight.
- Nút **⬇ Dữ liệu** trên header tải CSV đúng con số của từng biểu đồ đang hiển thị (theo bộ lọc), dùng cho các task phân tích tiếp theo.
- Chân trang ghi bảng nguồn và rule chung (đơn delivered, COUNT(DISTINCT order_id), GMV = price + freight, AOV, tháng đặt mua).
- Chưa có: cohort retention (GD4.5), churn score (GD4.8).
- Chạy nhanh trên Windows: nhấp đúp `run_dashboard.bat` ở gốc repo (tự tắt bản đang chạy rồi mở lại).
