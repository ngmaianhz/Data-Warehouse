{{
    config(
        tags=['gold', 'audit', 'financial']
    )
}}

-- ==============================================================================
-- GD3.28 - SINGULAR AUDIT TEST 1: ĐỐI SOÁT BẢO TOÀN SỐ DÒNG
-- ==============================================================================
-- Tiêu chuẩn: COUNT(fact_sales) = COUNT(silver_order_items) = 112,650 dòng
-- Nếu có sự chênh lệch số dòng, query sẽ trả về bản ghi lỗi.
-- ==============================================================================

WITH fact_count AS (
    SELECT COUNT(*) AS row_count FROM {{ ref('fact_sales') }}
),

silver_count AS (
    SELECT COUNT(*) AS row_count FROM {{ ref('silver_order_items') }}
)

SELECT 
    f.row_count AS fact_sales_rows,
    s.row_count AS silver_order_items_rows,
    ABS(f.row_count - s.row_count) AS row_delta
FROM fact_count f
CROSS JOIN silver_count s
WHERE f.row_count != s.row_count
   OR f.row_count != 112650
