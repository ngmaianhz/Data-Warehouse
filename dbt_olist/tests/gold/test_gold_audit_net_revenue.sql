{{
    config(
        tags=['gold', 'audit', 'financial']
    )
}}

-- ==============================================================================
-- GD3.28 - SINGULAR AUDIT TEST 2: ĐỐI SOÁT DOANH THU THUẦN (IFRS 15)
-- ==============================================================================
-- Tiêu chuẩn: SUM(fact_sales.price) = SUM(silver_order_items.price)
-- Độ lệch cho phép = 0.00 (Chính xác tuyệt đối)
-- ==============================================================================

WITH fact_price AS (
    SELECT ROUND(SUM(price), 2) AS total_fact_price FROM {{ ref('fact_sales') }}
),

silver_price AS (
    SELECT ROUND(SUM(price), 2) AS total_silver_price FROM {{ ref('silver_order_items') }}
)

SELECT 
    f.total_fact_price,
    s.total_silver_price,
    ROUND(f.total_fact_price - s.total_silver_price, 2) AS price_delta
FROM fact_price f
CROSS JOIN silver_price s
WHERE ROUND(f.total_fact_price - s.total_silver_price, 2) != 0.00
