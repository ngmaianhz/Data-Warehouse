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
-- Phụ thuộc : gold.fact_sales, gold.dim_customer, gold.fact_customer_reviews
-- Scope     : Chỉ tính các đơn order_status = 'delivered'
-- CLV       : Historical CLV = total_gmv (không tạo cột clv_historical riêng
--             vì định nghĩa trùng total_gmv — xem thiết kế GD4.4)
-- Delivery  : Các đặc trưng giao hàng phục vụ phân tích / ML (GD4.4)
-- ==============================================================================

-- ---------------------------------------------------------------------------
-- 1. Lấy tất cả các đơn hàng delivered từ fact_sales
--    Grain nguồn: 1 dòng / order_item (cần aggregate lên order, rồi lên customer)
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
        -- Dùng delivered_date_key để tính ngày giao thực tế
        delivered_date_key
    FROM {{ ref('fact_sales') }}
    WHERE order_status = 'delivered'
),

-- ---------------------------------------------------------------------------
-- 2. Aggregate lên cấp độ ORDER (loại bỏ fan-out trước khi lên customer)
-- ---------------------------------------------------------------------------
delivered_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        SUM(gmv)                        AS order_gmv,
        SUM(price)                      AS order_revenue,
        SUM(freight_value)              AS order_freight,
        SUM(allocated_payment_value)    AS order_payment,
        -- Lấy ngày giao hàng (1 đơn có 1 ngày giao duy nhất khi đã lọc delivered)
        MAX(delivered_date_key)         AS delivered_date_key,
        -- Phương thức thanh toán chủ đạo (ARG_MAX sẽ chọn giá trị lớn nhất)
        ARG_MAX(primary_payment_type_key, gmv) AS primary_payment_type_key
    FROM delivered_items
    GROUP BY customer_unique_id, order_id
),

-- ---------------------------------------------------------------------------
-- 3. Join với silver_orders để lấy các ngày mốc giao hàng chi tiết
--    (order_approved_at, order_delivered_carrier_date, order_delivered_customer_date,
--     order_estimated_delivery_date, order_purchase_timestamp)
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
        -- Delivery lead time (ngày từ đặt hàng đến giao thực tế)
        CASE
            WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_purchase_timestamp IS NOT NULL
            THEN date_diff('day', o.order_purchase_timestamp, o.order_delivered_customer_date)
            ELSE NULL
        END AS actual_lead_time_days,
        -- On-time delivery flag: giao trước hoặc đúng ngày dự kiến
        CASE
            WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
            THEN (o.order_delivered_customer_date <= o.order_estimated_delivery_date)
            ELSE NULL
        END AS is_on_time,
        -- Delay days: số ngày giao trễ (dương = trễ, âm = sớm)
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
-- 4. Aggregate lên cấp độ CUSTOMER — đây là grain cuối của mart
-- ---------------------------------------------------------------------------
customer_metrics AS (
    SELECT
        customer_unique_id,

        -- === Lịch sử mua hàng ===
        MIN(order_purchase_timestamp)           AS first_order_date,
        MAX(order_purchase_timestamp)           AS last_order_date,
        COUNT(DISTINCT order_id)                AS total_orders,

        -- === Giá trị mua hàng (GMV) ===
        ROUND(SUM(order_gmv), 2)                AS total_gmv,
        ROUND(SUM(order_revenue), 2)            AS total_revenue,
        ROUND(SUM(order_freight), 2)            AS total_freight_paid,

        -- === CLV Metrics (GD4.4) ===
        -- AOV = total_gmv / total_orders
        ROUND(
            CASE
                WHEN COUNT(DISTINCT order_id) > 0
                THEN SUM(order_gmv) / COUNT(DISTINCT order_id)
                ELSE 0
            END,
        2) AS aov,

        -- Khoảng thời gian giữa lần mua đầu và cuối (ngày)
        CASE
            WHEN COUNT(DISTINCT order_id) > 1
            THEN date_diff(
                'day',
                MIN(order_purchase_timestamp),
                MAX(order_purchase_timestamp)
            )
            ELSE 0
        END AS customer_lifespan_days,

        -- purchase_frequency = total_orders / lifespan (đơn/ngày), tránh div/0
        -- Nếu lifespan = 0 (chỉ 1 đơn) → frequency = 1.0 (đơn/kỳ quan sát)
        CASE
            WHEN COUNT(DISTINCT order_id) <= 1
                OR date_diff('day', MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)) = 0
            THEN 1.0
            ELSE ROUND(
                CAST(COUNT(DISTINCT order_id) AS DOUBLE)
                / date_diff('day', MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)),
            6)
        END AS purchase_frequency,

        -- === Delivery Features (GD4.4) ===
        ROUND(AVG(actual_lead_time_days), 2)    AS avg_lead_time_days,
        MIN(actual_lead_time_days)              AS min_lead_time_days,
        MAX(actual_lead_time_days)              AS max_lead_time_days,

        -- Tỷ lệ đơn giao đúng hạn
        ROUND(
            CAST(SUM(CASE WHEN is_on_time = true THEN 1 ELSE 0 END) AS DOUBLE)
            / NULLIF(COUNT(CASE WHEN is_on_time IS NOT NULL THEN 1 END), 0),
        4) AS on_time_delivery_rate,

        -- Số đơn giao đúng hạn / trễ
        SUM(CASE WHEN is_on_time = true THEN 1 ELSE 0 END)  AS orders_on_time,
        SUM(CASE WHEN is_on_time = false THEN 1 ELSE 0 END) AS orders_late,

        -- Trung bình số ngày trễ (dương = trễ, âm = sớm)
        ROUND(AVG(delivery_delay_days), 2)      AS avg_delivery_delay_days,

        -- Tổng freight đã trả
        ROUND(AVG(order_freight), 2)            AS avg_freight_per_order

    FROM orders_with_dates
    GROUP BY customer_unique_id
),

-- ---------------------------------------------------------------------------
-- 5. Join với dim_customer để bổ sung thông tin địa lý & cohort date
-- ---------------------------------------------------------------------------
customer_with_profile AS (
    SELECT
        m.*,
        dc.latest_city,
        dc.latest_state,
        dc.latest_zip_code_prefix,
        dc.latitude,
        dc.longitude,
        -- Cohort date từ dim_customer (ngày đặt đơn đầu tiên trong toàn bộ lịch sử)
        dc.first_order_date AS cohort_date
    FROM customer_metrics m
    LEFT JOIN {{ ref('dim_customer') }} dc
        ON m.customer_unique_id = dc.customer_unique_id
),

-- ---------------------------------------------------------------------------
-- 6. Join với fact_customer_reviews để tính avg_review_score
--    Dùng Bridge qua order_id để tránh fan-out
-- ---------------------------------------------------------------------------
order_reviews_agg AS (
    SELECT
        customer_unique_id,
        ROUND(AVG(review_score), 4)             AS avg_review_score,
        COUNT(DISTINCT order_id)                AS total_reviewed_orders,
        -- Tỷ lệ đánh giá tích cực (score >= 4)
        ROUND(
            CAST(SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) AS DOUBLE)
            / NULLIF(COUNT(*), 0),
        4) AS positive_review_rate
    FROM {{ ref('fact_customer_reviews') }}
    GROUP BY customer_unique_id
)

-- ---------------------------------------------------------------------------
-- 7. Final SELECT — mart_customer_360
-- ---------------------------------------------------------------------------
SELECT
    -- 0. Định danh
    p.customer_unique_id,

    -- 1. Thông tin địa lý (từ dim_customer)
    p.latest_city,
    p.latest_state,
    p.latest_zip_code_prefix,
    p.latitude,
    p.longitude,

    -- 2. Lịch sử mua hàng
    p.first_order_date,
    p.last_order_date,
    p.cohort_date,

    -- 3. Chỉ số tần suất & khối lượng
    p.total_orders,
    p.total_gmv,
    p.total_revenue,
    p.total_freight_paid,

    -- 4. CLV Metrics (GD4.4)
    p.aov,
    p.customer_lifespan_days,
    p.purchase_frequency,
    -- clv_historical KHÔNG được tạo riêng vì = total_gmv (tránh redundancy theo thiết kế)

    -- 5. Review metrics
    COALESCE(r.avg_review_score, NULL)          AS avg_review_score,
    COALESCE(r.total_reviewed_orders, 0)        AS total_reviewed_orders,
    COALESCE(r.positive_review_rate, NULL)      AS positive_review_rate,

    -- 6. Delivery Features (GD4.4)
    p.avg_lead_time_days,
    p.min_lead_time_days,
    p.max_lead_time_days,
    p.on_time_delivery_rate,
    p.orders_on_time,
    p.orders_late,
    p.avg_delivery_delay_days,
    p.avg_freight_per_order,

    -- 7. Audit
    CURRENT_TIMESTAMP AS dbt_created_at

FROM customer_with_profile p
LEFT JOIN order_reviews_agg r
    ON p.customer_unique_id = r.customer_unique_id

