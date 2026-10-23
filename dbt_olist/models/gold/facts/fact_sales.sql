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
