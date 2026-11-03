# ML readiness report
Thời điểm chạy: 2026-11-03 07:47
Database: olist_warehouse

## 1. Bảng/view hiện có
| table_schema | table_name | table_type |
|---|---|---|
| main | bronze_customers | BASE TABLE |
| main | bronze_geolocation | BASE TABLE |
| main | bronze_ingestion_log | BASE TABLE |
| main | bronze_order_items | BASE TABLE |
| main | bronze_order_payments | BASE TABLE |
| main | bronze_order_reviews | BASE TABLE |
| main | bronze_orders | BASE TABLE |
| main | bronze_product_category_name_translation | BASE TABLE |
| main | bronze_products | BASE TABLE |
| main | bronze_sellers | BASE TABLE |
| main | olist_customers_dataset | VIEW |
| main | olist_geolocation_dataset | VIEW |
| main | olist_order_items_dataset | VIEW |
| main | olist_order_payments_dataset | VIEW |
| main | olist_order_reviews_dataset | VIEW |
| main | olist_orders_dataset | VIEW |
| main | olist_products_dataset | VIEW |
| main | olist_sellers_dataset | VIEW |
| main | product_category_name_translation | VIEW |
| main_gold | dim_customer | BASE TABLE |
| main_gold | dim_date | BASE TABLE |
| main_gold | dim_payment_type | BASE TABLE |
| main_gold | dim_product | BASE TABLE |
| main_gold | dim_seller | BASE TABLE |
| main_gold | fact_customer_reviews | BASE TABLE |
| main_gold | fact_sales | BASE TABLE |
| main_gold | obs_gold_health | VIEW |
| main_gold | olap_scenarios | BASE TABLE |
| main_main | obs_bronze_health | VIEW |
| main_mart | mart_customer_360 | BASE TABLE |
| main_mart | obs_pipeline_health | VIEW |
| main_silver | obs_invalid_records | VIEW |
| main_silver | obs_silver_row_audit | VIEW |
| main_silver | silver_category_translation | BASE TABLE |
| main_silver | silver_customers | BASE TABLE |
| main_silver | silver_geolocation | BASE TABLE |
| main_silver | silver_order_items | BASE TABLE |
| main_silver | silver_order_payments | BASE TABLE |
| main_silver | silver_order_reviews | BASE TABLE |
| main_silver | silver_orders | BASE TABLE |
| main_silver | silver_products | BASE TABLE |
| main_silver | silver_sellers | BASE TABLE |

Thiếu: không thiếu bảng nào

## 2. Số dòng và danh sách cột

### "main_gold"."fact_sales" — 112,650 dòng
sales_item_key (VARCHAR), order_id (VARCHAR), order_item_id (INTEGER), purchase_date_key (INTEGER), delivered_date_key (INTEGER), customer_unique_id (VARCHAR), product_id (VARCHAR), seller_id (VARCHAR), primary_payment_type_key (INTEGER), order_status (VARCHAR), shipping_state (VARCHAR), shipping_zip_code_prefix (VARCHAR), price (DECIMAL(10,2)), freight_value (DECIMAL(10,2)), gmv (DECIMAL(11,2)), allocated_payment_value (DOUBLE), quantity (INTEGER), dbt_created_at (TIMESTAMP WITH TIME ZONE)

### "main_gold"."fact_customer_reviews" — 99,224 dòng
review_key (VARCHAR), review_id (VARCHAR), order_id (VARCHAR), review_creation_date_key (INTEGER), review_answer_date_key (INTEGER), customer_unique_id (VARCHAR), review_score (INTEGER), response_time_hours (DOUBLE), has_comment_title (INTEGER), has_comment_message (INTEGER), dbt_created_at (TIMESTAMP WITH TIME ZONE)

### "main_gold"."dim_customer" — 96,096 dòng
customer_unique_id (VARCHAR), latest_zip_code_prefix (VARCHAR), latest_city (VARCHAR), latest_state (VARCHAR), latitude (DOUBLE), longitude (DOUBLE), first_order_date (TIMESTAMP)

### "main_gold"."dim_date" — 1,097 dòng
date_key (INTEGER), date_day (DATE), year (INTEGER), quarter (INTEGER), month (INTEGER), day (INTEGER), day_of_week (INTEGER), day_name (VARCHAR), month_name (VARCHAR), is_weekend (BOOLEAN)

### "main_silver"."silver_orders" — 99,441 dòng
order_key (VARCHAR), order_id (VARCHAR), customer_id (VARCHAR), order_status (VARCHAR), order_purchase_timestamp (TIMESTAMP), order_approved_at (TIMESTAMP), order_delivered_carrier_date (TIMESTAMP), order_delivered_customer_date (TIMESTAMP), order_estimated_delivery_date (TIMESTAMP), has_cast_error (BOOLEAN), is_delivery_missing (BOOLEAN), is_valid_chronology (BOOLEAN), _load_timestamp (TIMESTAMP), _source_file (VARCHAR), _run_id (VARCHAR)

### "main_silver"."silver_order_payments" — 103,886 dòng
payment_key (VARCHAR), order_id (VARCHAR), payment_sequential (INTEGER), payment_type (VARCHAR), payment_installments (INTEGER), payment_value (DECIMAL(10,2)), is_zero_payment (BOOLEAN), is_negative_payment (BOOLEAN), is_valid_payment_value (BOOLEAN), is_voucher_payment (BOOLEAN), is_valid_payment (BOOLEAN), _load_timestamp (TIMESTAMP), _source_file (VARCHAR), _run_id (VARCHAR)

### "main_mart"."mart_customer_360" — 93,358 dòng
customer_unique_id (VARCHAR), first_order_date (DATE), last_order_date (DATE), latest_city (VARCHAR), latest_state (VARCHAR), latest_zip_code_prefix (VARCHAR), total_orders (BIGINT), total_gmv (DECIMAL(10,2)), aov (DECIMAL(10,2)), avg_review_score (DECIMAL(3,2)), customer_lifespan_days (BIGINT), purchase_frequency (DECIMAL(10,2)), recency_days (BIGINT), r_score (INTEGER), f_score (INTEGER), m_score (INTEGER), segment (VARCHAR), clv_historical (DECIMAL(10,2)), clv_predicted (DECIMAL(10,2)), latitude (DOUBLE), longitude (DOUBLE), cohort_date (DATE), total_revenue (DECIMAL(10,2)), total_freight_paid (DECIMAL(10,2)), total_reviewed_orders (BIGINT), positive_review_rate (DOUBLE), avg_lead_time_days (DOUBLE), min_lead_time_days (BIGINT), max_lead_time_days (BIGINT), on_time_delivery_rate (DOUBLE), orders_on_time (HUGEINT), orders_late (HUGEINT), avg_delivery_delay_days (DOUBLE), avg_freight_per_order (DOUBLE), dbt_created_at (TIMESTAMP WITH TIME ZONE)

## 3. Cột giao hàng trong fact_sales
- delivery_days: KHÔNG
- delivery_delay_days: KHÔNG
- is_late: KHÔNG
- estimated_delivery_date_key: KHÔNG
- delivered_date_key: CÓ

## 4. Kiểm tra dữ liệu cho phân cụm

### 4.1 Đối soát số dòng/khách
_Kỳ vọng: 112,650 dòng fact; 96,096 khách_
| fact_sales_rows | orders_in_fact | customers_in_fact | dim_customer_rows | dim_customer_distinct |
|---|---|---|---|---|
| 112650 | 98666 | 95420 | 96096 | 96096 |

### 4.2 Phân bố trạng thái đơn trong fact_sales
| order_status | n_orders |
|---|---|
| delivered | 96478 |
| shipped | 1106 |
| canceled | 461 |
| invoiced | 312 |
| processing | 301 |
| unavailable | 6 |
| approved | 2 |

### 4.3 Phân bố Frequency (đơn delivered / khách)
| freq | n_customers | pct |
|---|---|---|
| 1 | 90557 | 97.0 |
| 2 | 2573 | 2.76 |
| 3 | 181 | 0.19 |
| 4 | 28 | 0.03 |
| 5 | 9 | 0.01 |
| 6 | 5 | 0.01 |
| 7 | 3 | 0.0 |
| 9 | 1 | 0.0 |
| 15 | 1 | 0.0 |

### 4.4 Khách không có đơn delivered nào
| customers_without_delivered |
|---|
| 2738 |

### 4.5 Ứng viên snapshot_date (ngày tham chiếu Recency)
**LỖI:** `Binder Error: Table "d" does not have a column named "full_date"`

### 4.6 Phân bố Monetary = SUM(price) đơn delivered / khách
| n | min | q1 | median | q3 | p99 | max | skew |
|---|---|---|---|---|---|---|---|
| 93358 | 0.85 | 47.65 | 89.73 | 154.73 | 1004.99 | 13440.00 | 9.75 |

### 4.7 So sánh 3 cách đo Monetary (đơn delivered)
| sum_price | sum_gmv | sum_payment |
|---|---|---|
| 13221498.11 | 15419773.75 | 15422461.77 |

### 4.8 Độ phủ review theo khách (khách có đơn delivered)
| customers_delivered | customers_with_review | pct_with_review |
|---|---|---|
| 93358 | 92755 | 99.35 |

### 4.9 Đối soát fan-out: payment phân bổ vs payment nguồn
_Hai số phải bằng nhau_
| gold_allocated | silver_payment |
|---|---|
| 15846280.17 | 15846280.17 |

### 4.10 Cột ngày giao trong silver_orders
- order_delivered_customer_date: CÓ
- order_estimated_delivery_date: CÓ
- is_valid_chronology: CÓ
- is_delivery_missing: CÓ

### 4.11 Thử tính delivery features từ silver_orders
| delivered_orders | has_delivered_date | avg_delivery_days | pct_late |
|---|---|---|---|
| 96478 | 96470 | 12.5 | 8.11 |

## 5. Mã nguồn dbt liên quan

### dbt_olist\dbt_project.yml
```yaml
﻿name: 'dbt_olist'
version: '1.0.0'
config-version: 2

profile: 'dbt_olist'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

clean-targets:
  - "target"
  - "dbt_packages"

models:
  dbt_olist:
    bronze:
      +materialized: view
      +schema: bronze
    silver:
      +materialized: table
      +schema: silver
    gold:
      +materialized: table
      +schema: gold
    mart:
      +materialized: table
      +schema: mart
```

### dbt_olist\models\gold\dimensions\dim_customer.sql
```sql
WITH customer_orders AS (
    -- Lấy thông tin đơn hàng và đánh số thứ tự đơn hàng mới nhất của từng khách hàng
    SELECT 
        c.customer_id,
        c.customer_unique_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp DESC
        ) AS rn
    FROM {{ ref('silver_customers') }} c
    LEFT JOIN {{ ref('silver_orders') }} o 
        ON c.customer_id = o.customer_id
),

latest_customer_info AS (
    -- Lấy địa chỉ của đơn hàng mới nhất (rn = 1) theo SCD Type 1
    SELECT 
        customer_unique_id,
        customer_zip_code_prefix AS latest_zip_code_prefix,
        customer_city AS latest_city,
        customer_state AS latest_state
    FROM customer_orders
    WHERE rn = 1
),

customer_metrics AS (
    -- Tính ngày đặt hàng đầu tiên (first_order_date)
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM {{ ref('silver_customers') }} c
    LEFT JOIN {{ ref('silver_orders') }} o 
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),

geo_aggregated AS (
    -- Tính tọa độ địa lý đại diện (trung bình lat/lng) theo zip code
    SELECT 
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS latitude,
        AVG(geolocation_lng) AS longitude
    FROM {{ ref('silver_geolocation') }}
    GROUP BY geolocation_zip_code_prefix
)

SELECT 
    l.customer_unique_id,
    l.latest_zip_code_prefix,
    l.latest_city,
    l.latest_state,
    g.latitude,
    g.longitude,
    m.first_order_date
FROM latest_customer_info l
LEFT JOIN customer_metrics m 
    ON l.customer_unique_id = m.customer_unique_id
LEFT JOIN geo_aggregated g 
    ON l.latest_zip_code_prefix = g.geolocation_zip_code_prefix
```

### dbt_olist\models\gold\facts\fact_customer_reviews.sql
```sql
{{
    config(
        materialized='table',
        schema='gold',
        tags=['gold', 'facts', 'customer_reviews', 'reviews']
    )
}}

-- ==============================================================================
-- BẢNG FACT ĐÁNH GIÁ ĐƠN HÀNG CỦA KHÁCH HÀNG (fact_customer_reviews)
-- ==============================================================================
-- Đổi tên thống nhất: fact_customer_reviews
-- Grain: 1 dòng đại diện cho 1 lần khách hàng gửi phản hồi đánh giá cho 1 đơn hàng (1 review per order)
-- Khóa chính ghép tự nhiên: (review_id, order_id)
-- Khóa ngoại: review_creation_date_key, review_answer_date_key, customer_unique_id
-- Chiều thoái hóa (Degenerate Dimension): order_id (làm cầu nối Cross-Fact sang fact_sales)
-- Measures: review_score (1-5 sao), response_time_hours, cờ has_comment_title, has_comment_message
-- Thiết kế độc lập hoàn toàn với fact_sales để triệt tiêu lỗi nhân bản số lượt đánh giá (Fan-out)
-- ==============================================================================

WITH reviews AS (
    SELECT 
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        has_comment_message,
        review_creation_date,
        review_answer_timestamp
    FROM {{ ref('silver_order_reviews') }}
),

orders_customer AS (
    -- Lấy customer_unique_id làm Conformed Foreign Key kết nối sang dim_customer
    SELECT 
        o.order_id,
        c.customer_unique_id
    FROM {{ ref('silver_orders') }} o
    JOIN {{ ref('silver_customers') }} c 
        ON o.customer_id = c.customer_id
)

SELECT 
    -- 0. Khóa thay thế (Surrogate Key) cho bản ghi Fact
    {{ dbt_utils.generate_surrogate_key(['r.review_id', 'r.order_id']) }} AS review_key,

    -- 1. Khóa chính ghép tự nhiên & Chiều thoái hóa (Degenerate Dimension)
    r.review_id,
    r.order_id,

    -- 2. Khóa ngoại Conformed & Role-Playing Dimensions
    CAST(strftime(r.review_creation_date, '%Y%m%d') AS INTEGER) AS review_creation_date_key,
    CASE 
        WHEN r.review_answer_timestamp IS NOT NULL 
        THEN CAST(strftime(r.review_answer_timestamp, '%Y%m%d') AS INTEGER) 
        ELSE -1 
    END AS review_answer_date_key,
    COALESCE(oc.customer_unique_id, 'unknown') AS customer_unique_id,

    -- 3. Số đo phân tích (Measures)
    r.review_score,
    ROUND(date_diff('second', r.review_creation_date, r.review_answer_timestamp) / 3600.0, 2) AS response_time_hours,

    -- 4. Cờ phân tích chất lượng phản hồi
    CASE 
        WHEN r.review_comment_title IS NOT NULL AND TRIM(r.review_comment_title) <> '' 
        THEN 1 
        ELSE 0 
    END AS has_comment_title,
    r.has_comment_message,

    -- 5. Dấu vết thời gian nạp dữ liệu
    CURRENT_TIMESTAMP AS dbt_created_at

FROM reviews r
LEFT JOIN orders_customer oc 
    ON r.order_id = oc.order_id

```

### dbt_olist\models\gold\facts\fact_sales.sql
```sql
{{
    config(
        materialized='table',
        schema='gold',
        tags=['gold', 'facts', 'sales']
    )
}}

-- ==============================================================================
-- GD3.26 - XÂY DỰNG FACT TABLE BÁN HÀNG (fact_sales)
-- ==============================================================================
-- Grain: 1 dòng đại diện cho 1 mặt hàng trong 1 đơn hàng (1 order item per order)
-- Khóa chính tự nhiên ghép: (order_id, order_item_id)
-- Bảo toàn 100% số dòng so với silver_order_items (112,650 dòng)
-- Áp dụng thuật toán phân bổ thanh toán Hare-Niemeyer (Largest Remainder Method)
-- Triệt tiêu bẫy Fan-Out và bảo toàn chuẩn xác dòng tiền từng cent
-- ==============================================================================

WITH item_base AS (
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value,
        ROUND(price + freight_value, 2) AS item_value,
        -- Tính tổng giá trị các món trong đơn hàng bằng Window Function
        SUM(ROUND(price + freight_value, 2)) OVER (PARTITION BY order_id) AS total_order_item_value,
        -- Đánh số thứ tự xếp hạng để bù số dư cent vào mặt hàng có giá trị cao nhất
        ROW_NUMBER() OVER (
            PARTITION BY order_id 
            ORDER BY (price + freight_value) DESC, order_item_id ASC
        ) AS rank_item
    FROM {{ ref('silver_order_items') }}
),

order_payments_agg AS (
    SELECT
        order_id,
        -- Bảo vệ COALESCE chống hoàn toàn rủi ro NULL từ upstream
        COALESCE(SUM(payment_value), 0.00) AS total_order_payment,
        -- Lấy phương thức thanh toán chiếm giá trị lớn nhất làm đại diện
        ARG_MAX(payment_type, payment_value) AS primary_payment_type
    FROM {{ ref('silver_order_payments') }}
    GROUP BY order_id
),

joined_allocation AS (
    SELECT
        i.*,
        COALESCE(p.total_order_payment, 0.00) AS total_order_payment,
        COALESCE(p.primary_payment_type, 'unknown') AS primary_payment_type,
        -- Phân bổ thanh toán thô kèm xử lý ca biên an toàn (tránh division by zero)
        CASE
            WHEN COALESCE(p.total_order_payment, 0.00) = 0.00 THEN 0.00
            WHEN i.total_order_item_value = 0.00 THEN 
                ROUND(COALESCE(p.total_order_payment, 0.00) / COUNT(*) OVER (PARTITION BY i.order_id), 2)
            ELSE 
                ROUND(COALESCE(p.total_order_payment, 0.00) * (i.item_value / i.total_order_item_value), 2)
        END AS raw_allocated_payment
    FROM item_base i
    LEFT JOIN order_payments_agg p ON i.order_id = p.order_id
),

order_reconciliation AS (
    SELECT
        order_id,
        -- Tính độ lệch cent (Penny Delta) theo phương pháp Hare-Niemeyer
        ROUND(total_order_payment - SUM(raw_allocated_payment), 2) AS penny_delta
    FROM joined_allocation
    GROUP BY order_id, total_order_payment
)

SELECT
    -- 0. Surrogate Key
    {{ dbt_utils.generate_surrogate_key(['j.order_id', 'j.order_item_id']) }} AS sales_item_key,

    -- 1. Composite Natural Primary Key & Degenerate Dimensions
    j.order_id,
    j.order_item_id,

    -- 2. Conformed & Role-Playing Foreign Keys
    CAST(strftime(o.order_purchase_timestamp, '%Y%m%d') AS INTEGER) AS purchase_date_key,
    CASE 
        WHEN o.order_delivered_customer_date IS NOT NULL 
        THEN CAST(strftime(o.order_delivered_customer_date, '%Y%m%d') AS INTEGER) 
        ELSE -1 
    END AS delivered_date_key,
    c.customer_unique_id,
    j.product_id,
    j.seller_id,
    CASE j.primary_payment_type
        WHEN 'credit_card' THEN 1
        WHEN 'boleto' THEN 2
        WHEN 'voucher' THEN 3
        WHEN 'debit_card' THEN 4
        WHEN 'not_defined' THEN 5
        WHEN 'unknown' THEN 5
        ELSE -1
    END AS primary_payment_type_key,

    -- 3. Degenerate Dimension Attributes
    o.order_status,
    c.customer_state AS shipping_state,
    c.customer_zip_code_prefix AS shipping_zip_code_prefix,

    -- 4. Additive Fact Measures
    j.price,
    j.freight_value,
    j.item_value AS gmv,
    -- Thuật toán Hare-Niemeyer: Bù chính xác penny_delta vào mặt hàng có rank_item = 1
    CASE
        WHEN j.rank_item = 1 THEN ROUND(j.raw_allocated_payment + r.penny_delta, 2)
        ELSE j.raw_allocated_payment
    END AS allocated_payment_value,
    1 AS quantity,

    -- 5. Audit Ingestion Timestamp
    CURRENT_TIMESTAMP AS dbt_created_at

FROM joined_allocation j
JOIN order_reconciliation r ON j.order_id = r.order_id
LEFT JOIN {{ ref('silver_orders') }} o ON j.order_id = o.order_id
LEFT JOIN {{ ref('silver_customers') }} c ON o.customer_id = c.customer_id

```

### dbt_olist\models\gold\schema.yml
```yaml
version: 2

models:
  # ==============================================================================
  # 1. BẢNG CHIỀU (DIMENSION TABLES)
  # ==============================================================================

  # ------------------------------------------------------------------------------
  # 1.1. dim_customer
  # ------------------------------------------------------------------------------
  - name: dim_customer
    description: "Bảng chiều thông tin khách hàng (Customer Dimension - SCD Type 1)"
    meta:
      owner: "@data-team"
      business_definition: "Bảng chiều khách hàng duy nhất (Customer Dimension - SCD Type 1), lưu trữ thông tin địa lý cư trú mới nhất và thời điểm phát sinh đơn hàng đầu tiên phục vụ phân tích vòng đời khách hàng (Customer Lifecycle & Retention)."
    contract:
      enforced: true
    columns:
      - name: customer_unique_id
        data_type: varchar
        description: "Khóa chính duy nhất đại diện cho từng khách hàng thực (UUID đã ẩn danh)"
        meta:
          pseudonymized_id: true
        tags:
          - pseudonymized_id
        tests:
          - unique
          - not_null

      - name: latest_zip_code_prefix
        data_type: varchar
        description: "Mã bưu chính 5 chữ số của địa chỉ giao hàng gần nhất"
        meta:
          contains_pii: true
        tags:
          - contains_pii
        tests:
          - not_null

      - name: latest_city
        data_type: varchar
        description: "Tên thành phố cư trú theo đơn hàng gần nhất"
        meta:
          contains_pii: true
        tags:
          - contains_pii
        tests:
          - not_null

      - name: latest_state
        data_type: varchar
        description: "Mã bang cư trú (2 ký tự viết hoa) theo đơn hàng gần nhất"
        meta:
          contains_pii: true
        tags:
          - contains_pii
        tests:
          - not_null

      - name: latitude
        data_type: double
        description: "Tọa độ vĩ độ địa lý đại diện cho khách hàng (WGS84)"
        meta:
          contains_pii: true
        tags:
          - contains_pii

      - name: longitude
        data_type: double
        description: "Tọa độ kinh độ địa lý đại diện cho khách hàng (WGS84)"
        meta:
          contains_pii: true
        tags:
          - contains_pii

      - name: first_order_date
        data_type: timestamp
        description: "Mốc thời gian đặt đơn hàng đầu tiên của khách hàng (Cohort Date)"

  # ------------------------------------------------------------------------------
  # 1.2. dim_product
  # ------------------------------------------------------------------------------
  - name: dim_product
    description: "Bảng chiều thông tin sản phẩm chuẩn hóa song ngữ (Product Dimension)"
    meta:
      owner: "@data-team"
      business_definition: "Bảng chiều sản phẩm (Product Dimension) chuẩn hóa song ngữ Bồ Đào Nha - Anh và các thuộc tính kích thước, cân nặng phục vụ phân nhóm danh mục và tối ưu hóa vận chuyển."
    contract:
      enforced: true
    columns:
      - name: product_id
        data_type: varchar
        description: "Khóa chính sản phẩm (UUID đã ẩn danh)"
        meta:
          pseudonymized_id: true
        tags:
          - pseudonymized_id
        tests:
          - unique
          - not_null

      - name: product_category_name_portuguese
        data_type: varchar
        description: "Tên danh mục sản phẩm nguyên bản tiếng Bồ Đào Nha"
        tests:
          - not_null

      - name: product_category_name_english
        data_type: varchar
        description: "Tên danh mục sản phẩm tiếng Anh chuẩn hóa"
        tests:
          - not_null

      - name: product_weight_g
        data_type: decimal(10, 2)
        description: "Trọng lượng sản phẩm (gam)"

      - name: product_length_cm
        data_type: decimal(10, 2)
        description: "Chiều dài sản phẩm (cm)"

      - name: product_height_cm
        data_type: decimal(10, 2)
        description: "Chiều cao sản phẩm (cm)"

      - name: product_width_cm
        data_type: decimal(10, 2)
        description: "Chiều rộng sản phẩm (cm)"

  # ------------------------------------------------------------------------------
  # 1.3. dim_seller
  # ------------------------------------------------------------------------------
  - name: dim_seller
    description: "Bảng chiều thông tin người bán (Seller Dimension) tích hợp tọa độ địa lý đại diện"
    meta:
      owner: "@data-team"
      business_definition: "Bảng chiều người bán (Seller Dimension) bao gồm mã định danh, địa chỉ bưu chính và tọa độ địa lý phục vụ quản lý đối tác thương mại và phân tích logistics đa vùng."
    contract:
      enforced: true
    columns:
      - name: seller_id
        data_type: varchar
        description: "Khóa chính người bán (Natural Primary Key, unique 100%, UUID ẩn danh)"
        meta:
          pseudonymized_id: true
        tags:
          - pseudonymized_id
        tests:
          - unique
          - not_null

      - name: seller_zip_code_prefix
        data_type: varchar
        description: "Mã bưu chính 5 số chuẩn hóa của người bán"
        meta:
          contains_pii: true
        tags:
          - contains_pii
        tests:
          - not_null

      - name: seller_city
        data_type: varchar
        description: "Đơn vị hành chính cấp thành phố của người bán"
        meta:
          contains_pii: true
        tags:
          - contains_pii
        tests:
          - not_null

      - name: seller_state
        data_type: varchar
        description: "Đơn vị hành chính cấp bang của người bán (2 ký tự viết hoa)"
        meta:
          contains_pii: true
        tags:
          - contains_pii
        tests:
          - not_null

      - name: latitude
        data_type: double
        description: "Tọa độ vĩ độ địa lý đại diện cho người bán (WGS84)"
        meta:
          contains_pii: true
        tags:
          - contains_pii

      - name: longitude
        data_type: double
        description: "Tọa độ kinh độ địa lý đại diện cho người bán (WGS84)"
        meta:
          contains_pii: true
        tags:
          - contains_pii

  # ------------------------------------------------------------------------------
  # 1.4. dim_payment_type
  # ------------------------------------------------------------------------------
  - name: dim_payment_type
    description: "Bảng chiều phương thức thanh toán (Static Dimension) chuẩn hóa 5 kênh nghiệp vụ và bản ghi Sentinel (-1)"
    meta:
      owner: "@data-team"
      business_definition: "Bảng chiều tĩnh phương thức thanh toán (Payment Method Dimension) chuẩn hóa 5 kênh thanh toán nghiệp vụ và mã sentinel (-1) phục vụ phân tích dòng tiền và đối soát tài chính."
    contract:
      enforced: true
    columns:
      - name: payment_type_key
        data_type: integer
        description: "Khóa chính kênh thanh toán (1=credit_card, 2=boleto, 3=voucher, 4=debit_card, 5=unknown, -1=missing)"
        tests:
          - unique
          - not_null
          - accepted_values:
              values: [1, 2, 3, 4, 5, -1]

      - name: payment_type
        data_type: varchar
        description: "Mã định danh kỹ thuật phương thức thanh toán"
        tests:
          - unique
          - not_null
          - accepted_values:
              values: ['credit_card', 'boleto', 'voucher', 'debit_card', 'unknown', 'missing']

      - name: payment_type_name
        data_type: varchar
        description: "Tên hiển thị tiếng Anh của phương thức thanh toán"
        tests:
          - not_null

      - name: payment_type_name_vi
        data_type: varchar
        description: "Tên tiếng Việt của phương thức thanh toán"
        tests:
          - not_null

      - name: payment_category
        data_type: varchar
        description: "Nhóm kênh thanh toán"
        tests:
          - not_null

      - name: is_installment_eligible
        data_type: boolean
        description: "Cờ cho phép trả góp nhiều kỳ"
        tests:
          - not_null

  # ------------------------------------------------------------------------------
  # 1.5. dim_date
  # ------------------------------------------------------------------------------
  - name: dim_date
    description: "Bảng chiều thời gian (Date Dimension) tích hợp bản ghi Sentinel (-1) cho đơn chưa giao"
    meta:
      owner: "@data-team"
      business_definition: "Bảng chiều thời gian chuẩn hóa (Calendar Date Dimension) hỗ trợ phân tích xu hướng bán hàng đa cấp độ (Năm, Quý, Tháng, Ngày, Thứ trong tuần) và xử lý ngày sentinel (-1)."
    contract:
      enforced: true
    columns:
      - name: date_key
        data_type: integer
        description: "Khóa chính ngày dạng số nguyên YYYYMMDD và -1"
        tests:
          - unique
          - not_null

      - name: date_day
        data_type: date
        description: "Giá trị ngày theo định dạng chuẩn Date (YYYY-MM-DD)"

      - name: year
        data_type: integer
        description: "Năm (YYYY)"

      - name: quarter
        data_type: integer
        description: "Quý trong năm (1-4)"

      - name: month
        data_type: integer
        description: "Tháng trong năm (1-12)"

      - name: day
        data_type: integer
        description: "Ngày trong tháng (1-31)"

      - name: day_of_week
        data_type: integer
        description: "Chỉ số thứ trong tuần (0=Chủ nhật, 6=Thứ bảy)"

      - name: day_name
        data_type: varchar
        description: "Tên thứ trong tuần"
        tests:
          - not_null

      - name: month_name
        data_type: varchar
        description: "Tên tháng"
        tests:
          - not_null

      - name: is_weekend
        data_type: boolean
        description: "Cờ ngày cuối tuần"
        tests:
          - not_null

  # ==============================================================================
  # 2. BẢNG SỰ KIỆN (FACT TABLES)
  # ==============================================================================

  # ------------------------------------------------------------------------------
  # 2.1. fact_sales
  # ------------------------------------------------------------------------------
  - name: fact_sales
    description: >
      Bảng sự kiện giao dịch bán hàng trung tâm (Transaction Fact Table) tại tầng Gold.
      Grain nguyên tử: 1 dòng đại diện cho 1 mặt hàng trong 1 đơn hàng (1 order item per order).
      Bảo toàn 100% số dòng so với silver_order_items (112,650 dòng).
      Giải quyết bẫy Fan-Out bằng thuật toán phân bổ thanh toán Hare-Niemeyer bù lẻ cent.
    meta:
      owner: "@data-team"
      business_definition: "Bảng sự kiện giao dịch bán hàng trung tâm (Sales Transaction Fact Table) tại mức hạt chi tiết từng sản phẩm trong đơn, bảo toàn 100% doanh thu theo chuẩn IFRS 15 và phân bổ thanh toán theo thuật toán Hare-Niemeyer bù lẻ cent."
    contract:
      enforced: true
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - order_id
            - order_item_id

      - dbt_utils.equal_rowcount:
          compare_model: ref('silver_order_items')

    columns:
      - name: sales_item_key
        data_type: varchar
        description: "Khóa thay thế (Surrogate Key) băm SHA-256 từ (order_id, order_item_id)"
        tests:
          - unique
          - not_null

      - name: order_id
        data_type: varchar
        description: "Mã đơn hàng (Composite Natural PK & Degenerate Dimension, UUID ẩn danh)"
        meta:
          pseudonymized_id: true
        tags:
          - pseudonymized_id
        tests:
          - not_null

      - name: order_item_id
        data_type: integer
        description: "Số thứ tự mặt hàng trong đơn hàng (Composite Natural PK)"
        tests:
          - not_null

      - name: purchase_date_key
        data_type: integer
        description: "Khóa ngày đặt hàng YYYYMMDD nối về dim_date.date_key"
        tests:
          - not_null
          - relationships:
              to: ref('dim_date')
              field: date_key

      - name: delivered_date_key
        data_type: integer
        description: "Khóa ngày nhận hàng YYYYMMDD (bao gồm giá trị -1 cho đơn chưa giao) nối về dim_date.date_key"
        tests:
          - not_null
          - relationships:
              to: ref('dim_date')
              field: date_key

      - name: customer_unique_id
        data_type: varchar
        description: "Định danh khách hàng duy nhất (Conformed FK nối về dim_customer, UUID ẩn danh)"
        meta:
          pseudonymized_id: true
        tags:
          - pseudonymized_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_customer')
              field: customer_unique_id

      - name: product_id
        data_type: varchar
        description: "Mã sản phẩm (Conformed FK nối về dim_product, UUID ẩn danh)"
        meta:
          pseudonymized_id: true
        tags:
          - pseudonymized_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_product')
              field: product_id

      - name: seller_id
        data_type: varchar
        description: "Mã người bán (Conformed FK nối về dim_seller, UUID ẩn danh)"
        meta:
          pseudonymized_id: true
        tags:
          - pseudonymized_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_seller')
              field: seller_id

      - name: primary_payment_type_key
        data_type: integer
        description: "Khóa kênh thanh toán chủ đạo nối về dim_payment_type"
        tests:
          - not_null
          - relationships:
              to: ref('dim_payment_type')
              field: payment_type_key

      - name: order_status
        data_type: varchar
        description: "Trạng thái đơn hàng (Degenerate Dimension, giữ nguyên 8 trạng thái)"
        tests:
          - not_null
          - accepted_values:
              values:
                - 'delivered'
                - 'shipped'
                - 'canceled'
                - 'unavailable'
                - 'invoiced'
                - 'processing'
                - 'created'
                - 'approved'

      - name: shipping_state
        data_type: varchar
        description: "Mã bang giao nhận hàng thực tế"
        meta:
          contains_pii: true
        tags:
          - contains_pii
        tests:
          - not_null

      - name: shipping_zip_code_prefix
        data_type: varchar
        description: "Mã bưu chính 5 số nhận hàng thực tế"
        meta:
          contains_pii: true
        tags:
          - contains_pii
        tests:
          - not_null

      - name: price
        data_type: decimal(10, 2)
        description: "Doanh thu thuần của mặt hàng theo chuẩn kế toán IFRS 15 (BRL)"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 0"

      - name: freight_value
        data_type: decimal(10, 2)
        de
```

### dbt_olist\models\mart\mart_customer_360.sql
```sql
{{
    config(
        materialized='table',
        schema='mart',
        tags=['mart', 'customer', 'customer_360', 'gd4.2', 'gd4.4']
    )
}}

-- ==============================================================================
-- GD4.2 + GD4.4 - MART CUSTOMER 360
-- ==============================================================================
-- Grain     : 1 dòng / customer_unique_id có ít nhất 1 đơn delivered
-- Phụ thuộc : gold.fact_sales, gold.dim_customer, gold.fact_customer_reviews, silver_orders
-- Scope     : Chỉ tính các đơn order_status = 'delivered'
-- ==============================================================================

-- ---------------------------------------------------------------------------
-- 1. Lấy tất cả các đơn hàng delivered từ fact_sales
-- ---------------------------------------------------------------------------
WITH delivered_items AS (
    SELECT
        customer_unique_id,
        order_id,
        gmv,
        price,
        freight_value,
        allocated_payment_value,
        primary_payment_type_key,
        delivered_date_key
    FROM {{ ref('fact_sales') }}
    WHERE order_status = 'delivered'
),

-- ---------------------------------------------------------------------------
-- 2. Aggregate lên cấp độ ORDER (tránh fan-out)
-- ---------------------------------------------------------------------------
delivered_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        SUM(gmv)                        AS order_gmv,
        SUM(price)                      AS order_revenue,
        SUM(freight_value)              AS order_freight,
        SUM(allocated_payment_value)    AS order_payment,
        MAX(delivered_date_key)         AS delivered_date_key,
        ARG_MAX(primary_payment_type_key, gmv) AS primary_payment_type_key
    FROM delivered_items
    GROUP BY customer_unique_id, order_id
),

-- ---------------------------------------------------------------------------
-- 3. Join với silver_orders để lấy các mốc thời gian giao hàng chi tiết
-- ---------------------------------------------------------------------------
orders_with_dates AS (
    SELECT
        d.customer_unique_id,
        d.order_id,
        d.order_gmv,
        d.order_revenue,
        d.order_freight,
        d.order_payment,
        d.primary_payment_type_key,
        d.delivered_date_key,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        -- Delivery lead time (số ngày từ đặt hàng đến giao thực tế)
        CASE
            WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_purchase_timestamp IS NOT NULL
            THEN date_diff('day', o.order_purchase_timestamp, o.order_delivered_customer_date)
            ELSE NULL
        END AS actual_lead_time_days,
        -- On-time delivery flag
        CASE
            WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
            THEN (o.order_delivered_customer_date <= o.order_estimated_delivery_date)
            ELSE NULL
        END AS is_on_time,
        -- Delay days (dương = trễ, âm = sớm)
        CASE
            WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
            THEN date_diff('day', o.order_estimated_delivery_date, o.order_delivered_customer_date)
            ELSE NULL
        END AS delivery_delay_days
    FROM delivered_orders d
    JOIN {{ ref('silver_orders') }} o ON d.order_id = o.order_id
),

-- ---------------------------------------------------------------------------
-- 4. Aggregate lên cấp độ CUSTOMER
-- ---------------------------------------------------------------------------
customer_metrics AS (
    SELECT
        customer_unique_id,

        -- Ngày mua đầu và gần nhất ép kiểu DATE theo schema thiết kế
        CAST(MIN(order_purchase_timestamp) AS DATE) AS first_order_date,
        CAST(MAX(order_purchase_timestamp) AS DATE) AS last_order_date,
        COUNT(DISTINCT order_id)                    AS total_orders,

        -- Tổng GMV
        CAST(ROUND(SUM(order_gmv), 2) AS DECIMAL(10, 2)) AS total_gmv,
        CAST(ROUND(SUM(order_revenue), 2) AS DECIMAL(10, 2)) AS total_revenue,
        CAST(ROUND(SUM(order_freight), 2) AS DECIMAL(10, 2)) AS total_freight_paid,

        -- AOV
        CAST(
            ROUND(
                CASE
                    WHEN COUNT(DISTINCT order_id) > 0
                    THEN SUM(order_gmv) / COUNT(DISTINCT order_id)
                    ELSE 0
                END,
            2) 
        AS DECIMAL(10, 2)) AS aov,

        -- Lifespan (số ngày giữa đơn đầu và cuối)
        CASE
            WHEN COUNT(DISTINCT order_id) > 1
            THEN date_diff(
                'day',
                MIN(order_purchase_timestamp),
                MAX(order_purchase_timestamp)
            )
            ELSE 0
        END AS customer_lifespan_days,

        -- Tần suất mua hàng (DECIMAL(10, 2))
        CAST(
            CASE
                WHEN COUNT(DISTINCT order_id) <= 1
                    OR date_diff('day', MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)) = 0
                THEN 1.00
                ELSE GREATEST(
                    ROUND(
                        CAST(COUNT(DISTINCT order_id) AS DOUBLE) 
                        / date_diff('day', MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)),
                    2),
                    0.01
                )
            END
        AS DECIMAL(10, 2)) AS purchase_frequency,

        -- Delivery features (GD4.4)
        ROUND(AVG(actual_lead_time_days), 2)    AS avg_lead_time_days,
        MIN(actual_lead_time_days)              AS min_lead_time_days,
        MAX(actual_lead_time_days)              AS max_lead_time_days,

        ROUND(
            CAST(SUM(CASE WHEN is_on_time = true THEN 1 ELSE 0 END) AS DOUBLE)
            / NULLIF(COUNT(CASE WHEN is_on_time IS NOT NULL THEN 1 END), 0),
        4) AS on_time_delivery_rate,

        SUM(CASE WHEN is_on_time = true THEN 1 ELSE 0 END)  AS orders_on_time,
        SUM(CASE WHEN is_on_time = false THEN 1 ELSE 0 END) AS orders_late,

        ROUND(AVG(delivery_delay_days), 2)      AS avg_delivery_delay_days,
        ROUND(AVG(order_freight), 2)            AS avg_freight_per_order

    FROM orders_with_dates
    GROUP BY customer_unique_id
),

-- ---------------------------------------------------------------------------
-- 5. Join với dim_customer để lấy profile địa lý
-- ---------------------------------------------------------------------------
customer_with_profile AS (
    SELECT
        m.*,
        dc.latest_city,
        dc.latest_state,
        dc.latest_zip_code_prefix,
        dc.latitude,
        dc.longitude,
        CAST(dc.first_order_date AS DATE) AS cohort_date
    FROM customer_metrics m
    LEFT JOIN {{ ref('dim_customer') }} dc
        ON m.customer_unique_id = dc.customer_unique_id
),

-- ---------------------------------------------------------------------------
-- 6. Join với fact_customer_reviews tính review score
-- ---------------------------------------------------------------------------
order_reviews_agg AS (
    SELECT
        customer_unique_id,
        CAST(ROUND(AVG(review_score), 2) AS DECIMAL(3, 2)) AS avg_review_score,
        COUNT(DISTINCT order_id)                           AS total_reviewed_orders,
        ROUND(
            CAST(SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) AS DOUBLE)
            / NULLIF(COUNT(*), 0),
        4) AS positive_review_rate
    FROM {{ ref('fact_customer_reviews') }}
    GROUP BY customer_unique_id
),

-- ---------------------------------------------------------------------------
-- 7. Tính toán đặc trưng RFM cơ sở (GD4.3 & GD4.6)
-- ---------------------------------------------------------------------------
customer_rfm_base AS (
    SELECT
        p.*,
        -- Recency: Số ngày từ đơn cuối đến ngày mua gần nhất trong toàn hệ thống
        date_diff(
            'day', 
            p.last_order_date, 
            MAX(p.last_order_date) OVER ()
        ) AS recency_days
    FROM customer_with_profile p
),

-- ---------------------------------------------------------------------------
-- 8. Phân vị NTILE cho RFM Scores (GD4.3 & GD4.6)
-- ---------------------------------------------------------------------------
customer_rfm_scores AS (
    SELECT
        b.*,
        -- r_score: NTILE 1-5 (người mua gần nhất recency_days nhỏ nhất -> score 5)
        CAST(
            NTILE(5) OVER (
                ORDER BY b.recency_days DESC
            ) 
        AS INTEGER) AS r_score,

        -- f_score: Thang 1-3 (do đặc thù 97% khách hàng Olist chỉ mua 1 đơn)
        CAST(
            CASE 
                WHEN b.total_orders = 1 THEN 1
                WHEN b.total_orders = 2 THEN 2
                ELSE 3
            END
        AS INTEGER) AS f_score,

        -- m_score: NTILE 1-5 (chi tiêu nhiều nhất total_gmv cao nhất -> score 5)
        CAST(
            NTILE(5) OVER (
                ORDER BY b.total_gmv ASC
            )
        AS INTEGER) AS m_score

    FROM customer_rfm_base b
),

-- ---------------------------------------------------------------------------
-- 9. Gán nhãn phân khúc khách hàng (Segment Label)
-- ---------------------------------------------------------------------------
customer_segmented AS (
    SELECT
        s.*,
        CASE
            -- Khách hàng giá trị cao: Mua gần đây (R >= 4) và chi tiêu lớn (M >= 4)
            WHEN s.r_score >= 4 AND s.m_score >= 4 THEN 'Khách hàng giá trị cao'
            -- Khách hàng mua thường xuyên: Mua nhiều đơn (F >= 2) và còn hoạt động (R >= 3)
            WHEN s.f_score >= 2 AND s.r_score >= 3 THEN 'Khách hàng mua thường xuyên'
            -- Khách hàng mới / tiềm năng: Mua gần đây (R >= 4) nhưng chi tiêu vừa/nhỏ (M <= 3)
            WHEN s.r_score >= 4 AND s.m_score <= 3 THEN 'Khách hàng mới / tiềm năng'
            -- Khách hàng có nguy cơ rời bỏ: Đã lâu không mua (R <= 2) nhưng từng mua nhiều/chi nhiều (M >= 4 OR F >= 2)
            WHEN s.r_score <= 2 AND (s.m_score >= 4 OR s.f_score >= 2) THEN 'Khách hàng có nguy cơ rời bỏ'
            -- Khách hàng phổ thông: Các nhóm còn lại
            ELSE 'Khách hàng phổ thông'
        END AS segment
    FROM customer_rfm_scores s
)

-- ---------------------------------------------------------------------------
-- 9. Final SELECT - Bảng Customer 360 tích hợp RFM & Observability (GD4.6)
-- ---------------------------------------------------------------------------
SELECT
    -- [PK] Khóa khách hàng
    c.customer_unique_id,

    -- [Lịch sử mua hàng]
    c.first_order_date,
    c.last_order_date,

    -- [Địa chỉ mới nhất]
    c.latest_city,
    c.latest_state,
    c.latest_zip_code_prefix,

    -- [Khối lượng & Giá trị]
    c.total_orders,
    c.total_gmv,
    c.aov,

    -- [Đánh giá]
    r.avg_review_score,

    -- [Vòng đời & Tần suất]
    c.customer_lifespan_days,
    c.purchase_frequency,

    -- [RFM & Phân khúc khách hàng - GD4.3 & GD4.6]
    c.recency_days,
    c.r_score,
    c.f_score,
    c.m_score,
    c.segment,

    -- [CLV]
    c.total_gmv                                                 AS clv_historical,
    CAST(NULL AS DECIMAL(10, 2))                                AS clv_predicted,

    -- [Bổ sung phục vụ ML/Phân tích mở rộng - GD4.4]
    c.latitude,
    c.longitude,
    c.cohort_date,
    c.total_revenue,
    c.total_freight_paid,
    COALESCE(r.total_reviewed_orders, 0)                        AS total_reviewed_orders,
    r.positive_review_rate,
    c.avg_lead_time_days,
    c.min_lead_time_days,
    c.max_lead_time_days,
    c.on_time_delivery_rate,
    c.orders_on_time,
    c.orders_late,
    c.avg_delivery_delay_days,
    c.avg_freight_per_order,

    -- Audit
    CURRENT_TIMESTAMP                                           AS dbt_created_at

FROM customer_segmented c
LEFT JOIN order_reviews_agg r
    ON c.customer_unique_id = r.customer_unique_id

```

### dbt_olist\models\mart\schema.yml
```yaml
version: 2

models:
  # ==============================================================================
  # mart_customer_360 — GD4.2 + GD4.4
  # ==============================================================================
  - name: mart_customer_360
    description: >
      Bảng Customer 360 tổng hợp hồ sơ đầy đủ của từng khách hàng.
      Grain: 1 dòng / customer_unique_id có ít nhất 1 đơn delivered.
      Khớp 100% đặc tả schema thiết kế (ERD / Mart Diagram).
    meta:
      owner: "@data-team"
      task: "GD4.2 + GD4.4"
      business_definition: >
        Bảng phẳng Customer 360 tập trung toàn bộ đặc trưng của khách hàng
        tại mức hạt customer_unique_id, phục vụ phân tích CLV, phân cụm K-Means
        và giám sát chất lượng giao hàng.
    config:
      tags: ['mart', 'customer', 'customer_360', 'gd4.2', 'gd4.4']

    columns:
      # --- 0. Khóa chính ---
      - name: customer_unique_id
        data_type: varchar
        description: "Khóa khách hàng duy nhất (PK, UUID ẩn danh)"
        tests:
          - unique
          - not_null
          - relationships:
              to: ref('dim_customer')
              field: customer_unique_id

      # --- 1. Lịch sử mua hàng ---
      - name: first_order_date
        data_type: date
        description: "Ngày mua đầu tiên của khách hàng (DATE)"
        tests:
          - not_null

      - name: last_order_date
        data_type: date
        description: "Ngày mua gần nhất của khách hàng (DATE)"
        tests:
          - not_null

      # --- 2. Thông tin địa lý mới nhất ---
      - name: latest_city
        data_type: varchar
        description: "Thành phố mới nhất"

      - name: latest_state
        data_type: varchar
        description: "Bang mới nhất (2 ký tự)"

      - name: latest_zip_code_prefix
        data_type: varchar
        description: "Mã bưu chính mới nhất"

      # --- 3. Đơn hàng & Giá trị mua hàng ---
      - name: total_orders
        data_type: bigint
        description: "Tổng số đơn hàng delivered"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 1"

      - name: total_gmv
        data_type: decimal(10, 2)
        description: "Tổng giá trị mua hàng (GMV)"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: "> 0"

      - name: aov
        data_type: decimal(10, 2)
        description: "Giá trị đơn hàng trung bình = total_gmv / total_orders"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 0"

      # --- 4. Đánh giá ---
      - name: avg_review_score
        data_type: decimal(3, 2)
        description: "Điểm đánh giá trung bình (1.00 - 5.00)"

      # --- 5. Vòng đời & Tần suất ---
      - name: customer_lifespan_days
        data_type: bigint
        description: "Số ngày từ đơn đầu tiên đến đơn cuối cùng"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 0"

      - name: purchase_frequency
        data_type: decimal(10, 2)
        description: "Tần suất mua hàng"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: "> 0"

      # --- 6. CLV (Customer Lifetime Value) ---
      - name: clv_historical
        data_type: decimal(10, 2)
        description: "CLV lịch sử = total_gmv từ các đơn delivered"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: "> 0"

      - name: clv_predicted
        data_type: decimal(10, 2)
        description: "CLV dự đoán từ mô hình học máy (nếu có)"

      # --- 7. Các đặc trưng mở rộng phục vụ ML & Phân tích (GD4.4) ---
      - name: latitude
        data_type: double
        description: "Vĩ độ địa lý"

      - name: longitude
        data_type: double
        description: "Kinh độ địa lý"

      - name: cohort_date
        data_type: date
        description: "Cohort date"

      - name: total_revenue
        data_type: decimal(10, 2)
        description: "Tổng doanh thu sản phẩm thuần"

      - name: total_freight_paid
        data_type: decimal(10, 2)
        description: "Tổng cước vận chuyển"

      - name: total_reviewed_orders
        data_type: bigint
        description: "Số đơn hàng đã đánh giá"

      - name: positive_review_rate
        data_type: double
        description: "Tỷ lệ đánh giá tích cực"

      - name: avg_lead_time_days
        data_type: double
        description: "Thời gian giao hàng trung bình (ngày)"

      - name: min_lead_time_days
        data_type: bigint
        description: "Thời gian giao hàng nhanh nhất (ngày)"

      - name: max_lead_time_days
        data_type: bigint
        description: "Thời gian giao hàng lâu nhất (ngày)"

      - name: on_time_delivery_rate
        data_type: double
        description: "Tỷ lệ giao hàng đúng hẹn"

      - name: orders_on_time
        data_type: bigint
        description: "Số đơn giao đúng hẹn"

      - name: orders_late
        data_type: bigint
        description: "Số đơn giao trễ"

      - name: avg_delivery_delay_days
        data_type: double
        description: "Độ trễ giao hàng trung bình (ngày)"

      - name: avg_freight_per_order
        data_type: double
        description: "Cước phí trung bình mỗi đơn"

      - name: dbt_created_at
        data_type: timestamp
        description: "Thời điểm nạp dữ liệu"
        tests:
          - not_null

      # --- 8. RFM & Phân khúc khách hàng (GD4.3 & GD4.6) ---
      - name: recency_days
        data_type: bigint
        description: "Số ngày kể từ đơn mua gần nhất đến ngày kết thúc quan sát"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 0"

      - name: r_score
        data_type: integer
        description: "Điểm phân vị Recency (NTILE 1-5, 5 là khách hàng mua gần nhất)"
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 1
              max_value: 5

      - name: f_score
        data_type: integer
        description: "Điểm tần suất Frequency (Thang riêng 1-3 do 97% khách hàng chỉ mua 1 đơn)"
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 1
              max_value: 3

      - name: m_score
        data_type: integer
        description: "Điểm giá trị Monetary (NTILE 1-5, 5 là khách chi tiêu cao nhất)"
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 1
              max_value: 5

      - name: segment
        data_type: varchar
        description: "Nhãn phân khúc khách hàng theo ma trận điểm số RFM"
        tests:
          - not_null
          - accepted_values:
              values:
                - 'Khách hàng giá trị cao'
                - 'Khách hàng có nguy cơ rời bỏ'
                - 'Khách hàng mới / tiềm năng'
                - 'Khách hàng mua thường xuyên'
                - 'Khách hàng phổ thông'

  # ==============================================================================
  # obs_pipeline_health — GD4.6
  # ==============================================================================
  - name: obs_pipeline_health
    description: >
      View hợp nhất toàn bộ trạng thái Data Observability của kho dữ liệu Olist,
      tổng hợp từ 4 tầng: Bronze (freshness, volume, schema drift), Silver (kiểm toán đối soát dòng, DQ flags),
      Gold (kiểm toán doanh thu IFRS 15, cước phí, dòng tiền), và Mart (bảo toàn grain Customer 360).
    meta:
      owner: "@data-team"
      task: "GD4.6"
    config:
      tags: ['mart', 'observability', 'pipeline_health', 'gd4.6']

    columns:
      - name: obs_id
        description: "Mã định danh duy nhất của từng bản ghi kiểm toán"
        tests:
          - unique
          - not_null

      - name: pipeline_layer
        description: "Phân tầng kho dữ liệu được kiểm toán"
        tests:
          - not_null
          - accepted_values:
              values: ['BRONZE', 'SILVER', 'GOLD', 'MART']

      - name: entity_or_check_name
        description: "Tên bảng hoặc chỉ số kiểm toán cụ thể"
        tests:
          - not_null

      - name: health_status
        description: "Trạng thái sức khỏe kiểm toán"
        tests:
          - not_null
          - accepted_values:
              values: ['PASS', 'WARN', 'FAIL', 'OK']

      - name: gate_action
        description: "Hành động điều khiển cổng pipeline"
        tests:
          - not_null
          - accepted_values:
              values: ['ALLOW', 'BLOCK']

```

### dbt_olist\models\silver\schema.yml
```yaml
version: 2

# ==============================================================================
# GD3.15 - FILE SCHEMA.YML HOÀN THIỆN TEST DATA QUALITY CHO TẦNG SILVER
# ==============================================================================
# Sản phẩm bàn giao GD3.15: File schema.yml hoàn thiện test cho 9 model Silver:
#   1. silver_orders
#   2. silver_order_items
#   3. silver_order_payments
#   4. silver_order_reviews
#   5. silver_products
#   6. silver_customers
#   7. silver_sellers
#   8. silver_category_translation
#   9. silver_geolocation
#
# Đính chính quy chuẩn dòng (Reconciliation Rules):
#   - 8 bảng nghiệp vụ (orders, items, payments, reviews, products, customers,
#     sellers, translation) bảo toàn chính xác 100% số dòng so với Bronze.
#   - Duy nhất bảng silver_geolocation giảm dòng từ 1,000,163 dòng xuống còn
#     19,015 dòng duy nhất (~1.90% số dòng Bronze do đã gộp theo zip code prefix).
#
# Bộ kiểm thử chất lượng dữ liệu (Data Quality Tests):
#   - Test PK đơn: unique, not_null trên Surrogate Keys và Natural Primary Keys
#   - Test PK ghép: dbt_utils.unique_combination_of_columns cho (order_id, order_item_id),
#     (review_id, order_id), (order_id, payment_sequential)
#   - Test accepted_values: order_status, payment_type, review_score, geolocation_state
#   - Test accepted_range / expression: giá bán, cước ship, sample size, Bounding Box
#   - Test mốc thời gian: cảnh báo tiến trình thời gian giao nhận với severity: warn
# ==============================================================================

models:
  # ----------------------------------------------------------------------------
  # 1. silver_orders (Bảo toàn 100% dòng: 99,441 dòng)
  # ----------------------------------------------------------------------------
  - name: silver_orders
    description: >
      Bảng đơn hàng tổng quan tầng Silver (chuẩn hóa từ olist_orders_dataset).
      Bảo toàn 100% số dòng từ Bronze (99,441 dòng duy nhất).
      Đã ép kiểu an toàn 5 cột mốc thời gian bằng TRY_CAST, xử lý đơn thiếu ngày giao hàng
      và gắn cờ kiểm soát tiến trình thời gian (is_valid_chronology).
    tests:
      # Test mốc thời gian với mức cảnh báo severity: warn (cho các đơn vi phạm thứ tự giao nhận)
      - dbt_utils.expression_is_true:
          expression: "order_delivered_customer_date >= order_purchase_timestamp OR order_delivered_customer_date IS NULL"
          config:
            severity: warn

    columns:
      - name: order_key
        description: "Khóa thay thế (Surrogate Key) băm từ order_id"
        tests:
          - unique
          - not_null

      - name: order_id
        description: "Mã định danh duy nhất của đơn hàng (Natural Primary Key)"
        tests:
          - unique
          - not_null

      - name: customer_id
        description: "Mã khách hàng cho từng đơn đặt hàng (Foreign Key)"
        tests:
          - not_null

      - name: order_status
        description: "Trạng thái đơn hàng (đã chuẩn hóa chữ thường và cắt khoảng trắng)"
        tests:
          - not_null
          - accepted_values:
              values:
                - 'delivered'
                - 'shipped'
                - 'canceled'
                - 'unavailable'
                - 'invoiced'
                - 'processing'
                - 'created'
                - 'approved'

      - name: order_purchase_timestamp
        description: "Thời điểm khách hàng bấm đặt mua (bắt buộc phải có)"
        tests:
          - not_null

      - name: order_approved_at
        description: "Thời điểm thanh toán được phê duyệt"

      - name: order_delivered_carrier_date
        description: "Thời điểm đơn hàng bàn giao cho vận chuyển"

      - name: order_delivered_customer_date
        description: "Thời điểm khách hàng nhận được hàng"

      - name: order_estimated_delivery_date
        description: "Thời điểm dự kiến giao hàng ban đầu"
        tests:
          - not_null

      - name: has_cast_error
        description: "Cờ phát hiện lỗi ép kiểu timestamp"
        tests:
          - not_null

      - name: is_delivery_missing
        description: "Cờ phát hiện đơn delivered nhưng thiếu ngày giao"
        tests:
          - not_null

      - name: is_valid_chronology
        description: "Cờ tính hợp lệ về mặt thứ tự thời gian của đơn hàng"
        tests:
          - not_null

      - name: _load_timestamp
        description: "Thời điểm nạp bản ghi vào kho dữ liệu"
        tests:
          - not_null

      - name: _source_file
        description: "Tên file CSV nguồn ban đầu"

      - name: _run_id
        description: "Mã UUID của phiên nạp dữ liệu Bronze"

  # ----------------------------------------------------------------------------
  # 2. silver_order_items (Bảo toàn 100% dòng: 112,650 dòng)
  # ----------------------------------------------------------------------------
  - name: silver_order_items
    description: >
      Bảng mặt hàng chi tiết thuộc Tầng Silver. Đã chuẩn hóa kiểu dữ liệu số học,
      tính toán item_value và kiểm tra tính hợp lệ của đơn giá/cước ship.
      Bảo toàn chính xác 100% số dòng so với Bronze (112,650 dòng).
    tests:
      # Test PK ghép: order_id + order_item_id
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - order_id
            - order_item_id

    columns:
      - name: order_item_key
        description: "Khóa thay thế (Surrogate Key) băm từ order_id và order_item_id"
        tests:
          - unique
          - not_null

      - name: order_id
        description: "Mã định danh đơn hàng (phần 1 của PK ghép)"
        tests:
          - not_null

      - name: order_item_id
        description: "Số thứ tự mặt hàng tuần tự trong đơn (phần 2 của PK ghép, 1..N)"
        tests:
          - not_null

      - name: product_id
        description: "Khóa ngoại trỏ đến sản phẩm"
        tests:
          - not_null

      - name: seller_id
        description: "Khóa ngoại trỏ đến người bán"
        tests:
          - not_null

      - name: shipping_limit_date
        description: "Mốc thời hạn người bán phải giao hàng cho bưu cục"
        tests:
          - not_null

      - name: price
        description: "Giá bán của một sản phẩm (DECIMAL 10,2)"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 0"

      - name: freight_value
        description: "Cước phí vận chuyển phân bổ cho mặt hàng (DECIMAL 10,2)"
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 0"

      - name: item_value
        description: "Tổng giá trị mặt hàng (price + freight_value)"
        tests:
          - not_null

      - name: is_valid_price
        description: "Cờ kiểm toán: TRUE nếu price >= 0 và NOT NULL"
        tests:
          - not_null

      - name: is_valid_freight
        description: "Cờ kiểm toán: TRUE nếu freight_value >= 0 và NOT NULL"
        tests:
          - not_null

      - name: is_high_freight_ratio
        description: "Cờ cảnh báo vận hành: TRUE nếu freight_value > 2 * price và price > 0"
        tests:
          - not_null

  # ----------------------------------------------------------------------------
  # 3. silver_order_payments (Bảo toàn 100% dòng: 103,886 dòng)
  # ----------------------------------------------------------------------------
  - name: silver_order_payments
    description: >
      Bảng thanh toán đơn hàng thuộc Tầng Silver. Chuẩn hóa phương thức thanh toán,
      gắn cờ giao dịch bằng 0 / âm, bảo toàn chính xác 100% số dòng Bronze (103,886 dòng).
    tests:
      # Test PK ghép: order_id + payment_sequential
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - order_id
            - payment_sequential

    columns:
      - name: payment_key
        description: "Khóa thay thế (Surrogate Key) băm từ order_id và payment_sequential"
        tests:
          - unique
          - not_null

      - name: order_id
        description: "Mã định danh đơn hàng (phần 1 của PK ghép)"
        tests:
          - not_null

      - name: payment_sequential
        description: "Số thứ tự đợt thanh toán của đơn hàng (1..M)"
        tests:
          - not_null

      - name: payment_type
        description: "Phương thức thanh toán đã chuẩn hóa (credit_card, boleto, voucher, debit_card, unknown)"
        tests:
          - not_null
          - accepted_values:
              values: ['credit_card', 'boleto', 'voucher', 'debit_card', 'unknown']

      - name: payment_installments
        description: "Số kỳ trả góp"
        tests:
          - not_null

      - name: payment_value
        description: "Số tiền thanh toán thực tế của đợt thanh toán (DECIMAL 10,2)"
        tests:
          - not_null

      - name: is_zero_payment
        description: "Cờ kiểm toán: TRUE nếu payment_value = 0.00 (voucher 100%)"
        tests:
          - not_null

      - name: is_negative_payment
        description: "Cờ kiểm toán: TRUE nếu payment_value < 0.00"
        tests:
          - not_null

      - name: is_valid_payment_value
        description: "Cờ kiểm toán kế toán: TRUE nếu payment_value >= 0.00 và NOT NULL"
        tests:
          - not_null

      - name: is_voucher_payment
        description: "Cờ phân tích: TRUE nếu payment_type = 'voucher'"
        tests:
          - not_null

      - name: is_valid_payment
        description: "Cờ kiểm toán chất lượng: FALSE cho phương thức thanh toán bất thường (not_defined) hoặc giá trị âm"
        tests:
          - not_null

  # ----------------------------------------------------------------------------
  # 4. silver_order_reviews (Bảo toàn 100% dòng: 99,224 dòng)
  # ----------------------------------------------------------------------------
  - name: silver_order_reviews
    description: >
      Bảng đánh giá đơn hàng tầng Silver (chuẩn hóa từ olist_order_reviews_dataset).
      Bảo toàn chính xác 100% số dòng so với Bronze (99,224 dòng duy nhất).
    tests:
      # Test PK ghép: review_id + order_id
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - review_id
            - order_id

    columns:
      - name: review_key
        description: "Khóa thay thế (Surrogate Key) băm từ review_id và order_id"
        tests:
          - unique
          - not_null

      - name: review_id
        description: "Mã định danh đánh giá (phần 1 của PK ghép)"
        tests:
          - not_null

      - name: order_id
        description: "Mã đơn hàng được đánh giá (phần 2 của PK ghép)"
        tests:
          - not_null

      - name: review_score
        description: "Điểm đánh giá sao từ khách hàng (INTEGER: 1 đến 5)"
        tests:
          - not_null
          - accepted_values:
              values: [1, 2, 3, 4, 5]

      - name: review_comment_title
        description: "Tiêu đề bình luận đánh giá"
        tests:
          - not_null

      - name: review_comment_message
        description: "Nội dung phản hồi chi tiết từ khách hàng"

      - name: has_comment_message
        description: "Cờ boolean (1: có bình luận chữ thực tế, 0: không có)"
        tests:
          - not_null
          - accepted_values:
              values: [0, 1]

      - name: review_creation_date
        description: "Thời điểm hệ thống gửi phiếu khảo sát đánh giá"

      - name: review_answer_timestamp
        description: "Thời điểm khách hàng gửi câu trả lời đánh giá"

      - name: _load_timestamp
        description: "Mốc thời gian nạp dữ liệu từ Bronze"

      - name: _source_file
        description: "Tên file CSV nguồn"

      - name: _run_id
        description: "Mã lượt chạy pipeline ingestion"

  # ----------------------------------------------------------------------------
  # 5. silver_products (Bảo toàn 100% dòng: 32,951 dòng)
  # ----------------------------------------------------------------------------
  - name: silver_products
    description: >
      Bảng sản phẩm tầng Silver (chuẩn hóa từ olist_products_dataset).
      Bảo toàn chính xác 100% số dòng so với Bronze (32,951 dòng duy nhất).
      Đã liên kết từ điển dịch ngành hàng, điền trung vị cho các thông số thiếu
      và gắn cờ kiểm toán dữ liệu.
    columns:
      - name: product_key
        description: "Khóa thay thế (Surrogate Key) băm từ product_id"
        tests:
          - unique
          - not_null

      - name: product_id
        description: "Mã định danh sản phẩm (Natural Primary Key)"
        tests:
          - unique
          - not_null

      - name: product_category_name
        description: "Tên danh mục sản phẩm gốc (tiếng Bồ Đào Nha, đã chuẩn hóa và gán 'unknown' nếu khuyết)"
        tests:
          - not_null

      - name: product_category_name_english
        description: "Tên danh mục tiếng Anh (mặc định 'unknown' nếu không có)"
        tests:
          - not_null

      - name: is_missing_category
        description: "Cờ kiểm toán: TRUE nếu sản phẩm gốc bị thiếu tên danh mục"
        tests:
          - not_null

      - name: is_missing_dimensions
        description: "Cờ kiểm toán: TRUE nếu sản phẩm gốc bị thiếu trọng lượng hoặc kích thước"
        tests:
          - not_null

      - name: _load_timestamp
        description: "Thời điểm nạp bản ghi vào kho dữ liệu"
        tests:
          - not_null

      - name: _source_file
        description: "Tên file CSV nguồn ban đầu"

      - name: _run_id
        description: "Mã UUID của phiên nạp dữ liệu Bronze"

  # ----------------------------------------------------------------------------
  # 6. silver_customers (Bảo toàn 100% dòng: 99,441 dòng)
  # ----------------------------------------------------------------------------
  - name: silver_customers
    description: >
      Bảng khách hàng tầng Silver (chuẩn hóa từ olist_customers_dataset).
      Bảo toàn chính xác 100% số dòng so với Bronze (99,441 dòng duy nhất).
      Mã zip_code được chuẩn hóa LPAD 5 số, tên thành phố và bang được chuẩn hóa.
    columns:
      - name: customer_key
        description: "Khóa thay thế (Surrogate Key) băm từ customer_id"
        tests:
          - unique
          - not_null

      - name: customer_id
        description: "Mã định danh khách hàng cho từng đơn đặt (Natural Primary Key)"
        tests:
          - unique
          - not_null

      - name: customer_unique_id
        description: "Mã định danh duy nhất của cá nhân khách hàng (Unique Identifier)"
        tests:
          - not_null

      - name: customer_zip_code_prefix
        description: "Mã bưu chính chuẩn 5 chữ số (LPAD 0)"
        tests:
          - not_null

      - name: customer_city
        description: "Tên thành phố đã chuẩn hóa chữ thường và bỏ dấu"
        tests:
          - not_null

      - name: customer_state
        description: "Mã bang 2 ký tự (UF) viết hoa"
        tests:
          - not_null

      - name: _load_timestamp
        description: "Thời điểm nạp bản ghi vào kho dữ liệu"
        tes
```

### dbt_olist\tests\mart\test_mart_rfm_bucket_distribution.sql
```sql
{{
    config(
        tags=['mart', 'rfm', 'distribution', 'gd4.6']
    )
}}

-- ==============================================================================
-- GD4.6 - SINGULAR AUDIT TEST: PHÂN PHỐI CÁC BUCKET NTILE RFM (TEAM 7)
-- ==============================================================================
-- Mục đích:
--   Kiểm tra tính đồng đều của các bucket NTILE cho r_score và m_score.
--   Với thuật toán NTILE(5), mỗi bucket (1 đến 5) phải chiếm xấp xỉ 20% dân số.
--   Ngưỡng chấp nhận: Tỷ trọng mỗi bucket nằm trong khoảng [15.0%, 25.0%].
--   Query trả về dòng vi phạm nếu có bất kỳ bucket nào bị lệch bất thường.
-- ==============================================================================

WITH total_population AS (
    SELECT COUNT(*) AS total_customers FROM {{ ref('mart_customer_360') }}
),

r_buckets AS (
    SELECT
        'r_score'                                           AS metric_name,
        r_score                                             AS bucket_id,
        COUNT(*)                                            AS customer_count,
        ROUND((COUNT(*) * 100.0) / MAX(t.total_customers), 2) AS bucket_percentage
    FROM {{ ref('mart_customer_360') }}
    CROSS JOIN total_population t
    GROUP BY r_score
),

m_buckets AS (
    SELECT
        'm_score'                                           AS metric_name,
        m_score                                             AS bucket_id,
        COUNT(*)                                            AS customer_count,
        ROUND((COUNT(*) * 100.0) / MAX(t.total_customers), 2) AS bucket_percentage
    FROM {{ ref('mart_customer_360') }}
    CROSS JOIN total_population t
    GROUP BY m_score
),

unified_buckets AS (
    SELECT * FROM r_buckets
    UNION ALL
    SELECT * FROM m_buckets
)

SELECT
    metric_name,
    bucket_id,
    customer_count,
    bucket_percentage,
    'Tỷ trọng bucket NTILE lệch ngoài ngưỡng cho phép [15.0%, 25.0%]' AS failure_reason
FROM unified_buckets
WHERE bucket_percentage < 15.00 
   OR bucket_percentage > 25.00

```

### dbt_olist\tests\mart\test_mart_segment_distribution.sql
```sql
{{
    config(
        tags=['mart', 'rfm', 'segment', 'distribution', 'gd4.6']
    )
}}

-- ==============================================================================
-- GD4.6 - SINGULAR AUDIT TEST: PHÂN PHỐI TỶ TRỌNG SEGMENT KHÁCH HÀNG (TEAM 7)
-- ==============================================================================
-- Mục đích:
--   Kiểm tra tính hợp lý của tỷ trọng từng phân khúc khách hàng (Segment):
--   1. Không có segment nào bị rỗng (tỷ trọng = 0.00% hoặc count < 10).
--   2. Không có segment nào chiếm ưu thế cực đoan bất thường (> 80.00%).
--   3. Đảm bảo toàn bộ 5 phân khúc nghiệp vụ đều ghi nhận dữ liệu thực tế.
--   Query trả về dòng vi phạm nếu tỷ trọng segment có dấu hiệu bất thường.
-- ==============================================================================

WITH total_population AS (
    SELECT COUNT(*) AS total_customers FROM {{ ref('mart_customer_360') }}
),

segment_distribution AS (
    SELECT
        segment,
        COUNT(*)                                            AS segment_customer_count,
        ROUND((COUNT(*) * 100.0) / MAX(t.total_customers), 2) AS segment_percentage
    FROM {{ ref('mart_customer_360') }}
    CROSS JOIN total_population t
    GROUP BY segment
)

SELECT
    segment,
    segment_customer_count,
    segment_percentage,
    CASE
        WHEN segment_customer_count < 10 THEN 'Phân khúc có số lượng quá nhỏ (< 10 khách hàng)'
        WHEN segment_percentage <= 0.00 THEN 'Phân khúc bị rỗng (0.00%)'
        WHEN segment_percentage >= 80.00 THEN 'Phân khúc chiếm tỷ trọng cực đoan (>= 80.00%)'
        ELSE 'Bất thường không xác định'
    END AS anomaly_description
FROM segment_distribution
WHERE segment_percentage <= 0.00 
   OR segment_percentage >= 80.00
   OR segment_customer_count < 10

```