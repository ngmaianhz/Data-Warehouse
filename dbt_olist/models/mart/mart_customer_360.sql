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
