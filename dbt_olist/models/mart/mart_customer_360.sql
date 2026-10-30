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
            ROUND(
                CASE
                    WHEN COUNT(DISTINCT order_id) <= 1
                        OR date_diff('day', MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)) = 0
                    THEN 1.00
                    ELSE CAST(COUNT(DISTINCT order_id) AS DOUBLE) 
                         / date_diff('day', MIN(order_purchase_timestamp), MAX(order_purchase_timestamp))
                END,
            2)
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
)

-- ---------------------------------------------------------------------------
-- 7. Final SELECT - Khớp đúng 100% thứ tự & kiểu dữ liệu theo ảnh thiết kế
-- ---------------------------------------------------------------------------
SELECT
    -- [PK] Khóa khách hàng
    p.customer_unique_id,

    -- [Lịch sử mua hàng]
    p.first_order_date,
    p.last_order_date,

    -- [Địa chỉ mới nhất]
    p.latest_city,
    p.latest_state,
    p.latest_zip_code_prefix,

    -- [Khối lượng & Giá trị]
    p.total_orders,
    p.total_gmv,
    p.aov,

    -- [Đánh giá]
    r.avg_review_score,

    -- [Vòng đời & Tần suất]
    p.customer_lifespan_days,
    p.purchase_frequency,

    -- [CLV]
    p.total_gmv                                                 AS clv_historical,
    CAST(NULL AS DECIMAL(10, 2))                                AS clv_predicted,

    -- [Bổ sung phục vụ ML/Phân tích mở rộng - GD4.4]
    p.latitude,
    p.longitude,
    p.cohort_date,
    p.total_revenue,
    p.total_freight_paid,
    COALESCE(r.total_reviewed_orders, 0)                        AS total_reviewed_orders,
    r.positive_review_rate,
    p.avg_lead_time_days,
    p.min_lead_time_days,
    p.max_lead_time_days,
    p.on_time_delivery_rate,
    p.orders_on_time,
    p.orders_late,
    p.avg_delivery_delay_days,
    p.avg_freight_per_order,

    -- Audit
    CURRENT_TIMESTAMP                                           AS dbt_created_at

FROM customer_with_profile p
LEFT JOIN order_reviews_agg r
    ON p.customer_unique_id = r.customer_unique_id
