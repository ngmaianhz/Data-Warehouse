{{
    config(
        materialized='view',
        schema='silver',
        tags=['silver', 'observability', 'gate']
    )
}}

-- ==============================================================================
-- GD3.18 - OBSERVABILITY GATE BRONZE → SILVER: VIEW KIỂM TOÁN DÒNG (Team 7)
-- ==============================================================================
-- Mục đích:
--   1. Thiết lập cổng kiểm soát chất lượng dòng (Row Reconciliation Gate).
--   2. Bảng ngưỡng linh hoạt theo từng bảng (Flexible Thresholds):
--      - 8 bảng nghiệp vụ đạt chuẩn tuyệt đối 100.00% (bảo toàn nguyên vẹn số dòng).
--      - Duy nhất bảng silver_geolocation đạt ngưỡng linh hoạt ~1.90% (1.80% - 2.00%)
--        do đặc thù gộp nhóm centroid theo zip_code_prefix 5 số.
--   3. Xuất trạng thái kiểm toán (reconciliation_status) và quyết định Gate (ALLOW/BLOCK).
-- ==============================================================================

WITH thresholds AS (
    SELECT 
        1 AS stt, 
        'orders' AS entity_name, 
        'bronze_orders' AS bronze_source_table, 
        'silver_orders' AS silver_target_table, 
        100.00 AS min_threshold_pct, 
        100.00 AS max_threshold_pct, 
        'EXACT_100_PERCENT' AS threshold_type, 
        'Bảo toàn chính xác 100% số đơn hàng (99,441 dòng)' AS audit_rule_desc
    UNION ALL SELECT 2, 'order_items', 'bronze_order_items', 'silver_order_items', 100.00, 100.00, 'EXACT_100_PERCENT', 'Bảo toàn chính xác 100% số mặt hàng (112,650 dòng)'
    UNION ALL SELECT 3, 'order_payments', 'bronze_order_payments', 'silver_order_payments', 100.00, 100.00, 'EXACT_100_PERCENT', 'Bảo toàn chính xác 100% dòng thanh toán (103,886 dòng)'
    UNION ALL SELECT 4, 'order_reviews', 'bronze_order_reviews', 'silver_order_reviews', 100.00, 100.00, 'EXACT_100_PERCENT', 'Bảo toàn chính xác 100% dòng đánh giá (99,224 dòng)'
    UNION ALL SELECT 5, 'products', 'bronze_products', 'silver_products', 100.00, 100.00, 'EXACT_100_PERCENT', 'Bảo toàn chính xác 100% dòng sản phẩm (32,951 dòng)'
    UNION ALL SELECT 6, 'customers', 'bronze_customers', 'silver_customers', 100.00, 100.00, 'EXACT_100_PERCENT', 'Bảo toàn chính xác 100% dòng khách hàng (99,441 dòng)'
    UNION ALL SELECT 7, 'sellers', 'bronze_sellers', 'silver_sellers', 100.00, 100.00, 'EXACT_100_PERCENT', 'Bảo toàn chính xác 100% dòng người bán (3,095 dòng)'
    UNION ALL SELECT 8, 'category_translation', 'bronze_product_category_name_translation', 'silver_category_translation', 100.00, 100.00, 'EXACT_100_PERCENT', 'Bảo toàn chính xác 100% danh mục dịch (71 dòng)'
    UNION ALL SELECT 9, 'geolocation', 'bronze_geolocation', 'silver_geolocation', 1.80, 2.00, 'FLEXIBLE_RANGE_1.8_TO_2.0', 'Gộp theo zip_code_prefix loại trừ nhiễu (19,015 dòng ~1.90% Bronze)'
),

-- Lấy số dòng Bronze mới nhất theo đợt nạp thành công từ nhật ký kiểm toán
bronze_counts AS (
    SELECT
        table_name AS bronze_source_table,
        row_count_bronze AS bronze_row_count
    FROM (
        SELECT
            table_name,
            row_count_bronze,
            ROW_NUMBER() OVER (
                PARTITION BY table_name 
                ORDER BY load_timestamp DESC
            ) AS rn
        FROM {{ source('bronze', 'bronze_ingestion_log') }}
        WHERE status = 'SUCCESS'
    )
    WHERE rn = 1
),

-- Đếm số dòng thực tế từ 9 model tầng Silver
silver_counts AS (
    SELECT 'silver_orders' AS silver_target_table, count(*) AS silver_row_count FROM {{ ref('silver_orders') }}
    UNION ALL SELECT 'silver_order_items', count(*) FROM {{ ref('silver_order_items') }}
    UNION ALL SELECT 'silver_order_payments', count(*) FROM {{ ref('silver_order_payments') }}
    UNION ALL SELECT 'silver_order_reviews', count(*) FROM {{ ref('silver_order_reviews') }}
    UNION ALL SELECT 'silver_products', count(*) FROM {{ ref('silver_products') }}
    UNION ALL SELECT 'silver_customers', count(*) FROM {{ ref('silver_customers') }}
    UNION ALL SELECT 'silver_sellers', count(*) FROM {{ ref('silver_sellers') }}
    UNION ALL SELECT 'silver_category_translation', count(*) FROM {{ ref('silver_category_translation') }}
    UNION ALL SELECT 'silver_geolocation', count(*) FROM {{ ref('silver_geolocation') }}
)

SELECT
    t.stt,
    t.entity_name,
    t.bronze_source_table,
    t.silver_target_table,
    b.bronze_row_count,
    s.silver_row_count,
    ROUND((s.silver_row_count * 100.0) / b.bronze_row_count, 2) AS row_ratio_pct,
    t.min_threshold_pct,
    t.max_threshold_pct,
    t.threshold_type,
    CASE
        WHEN ROUND((s.silver_row_count * 100.0) / b.bronze_row_count, 2) >= t.min_threshold_pct 
         AND ROUND((s.silver_row_count * 100.0) / b.bronze_row_count, 2) <= t.max_threshold_pct 
        THEN 'PASS'
        ELSE 'FAIL'
    END AS reconciliation_status,
    CASE
        WHEN ROUND((s.silver_row_count * 100.0) / b.bronze_row_count, 2) >= t.min_threshold_pct 
         AND ROUND((s.silver_row_count * 100.0) / b.bronze_row_count, 2) <= t.max_threshold_pct 
        THEN 'ALLOW'
        ELSE 'BLOCK'
    END AS gate_action,
    t.audit_rule_desc
FROM thresholds t
JOIN bronze_counts b ON t.bronze_source_table = b.bronze_source_table
JOIN silver_counts s ON t.silver_target_table = s.silver_target_table
ORDER BY t.stt
