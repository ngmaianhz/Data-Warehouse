{{
    config(
        tags=['gold', 'audit', 'financial']
    )
}}

-- ==============================================================================
-- GD3.28 - SINGULAR AUDIT TEST 3: ĐỐI SOÁT CƯỚC PHÍ VẬN CHUYỂN
-- ==============================================================================
-- Tiêu chuẩn: SUM(fact_sales.freight_value) = SUM(silver_order_items.freight_value)
-- Độ lệch cho phép = 0.00 (Chính xác tuyệt đối)
-- ==============================================================================

WITH fact_freight AS (
    SELECT ROUND(SUM(freight_value), 2) AS total_fact_freight FROM {{ ref('fact_sales') }}
),

silver_freight AS (
    SELECT ROUND(SUM(freight_value), 2) AS total_silver_freight FROM {{ ref('silver_order_items') }}
)

SELECT 
    f.total_fact_freight,
    s.total_silver_freight,
    ROUND(f.total_fact_freight - s.total_silver_freight, 2) AS freight_delta
FROM fact_freight f
CROSS JOIN silver_freight s
WHERE ROUND(f.total_fact_freight - s.total_silver_freight, 2) != 0.00
