{{
    config(
        materialized='view',
        schema='mart',
        tags=['mart', 'observability', 'pipeline_health', 'gd4.6']
    )
}}

-- ==============================================================================
-- GD4.6 - DATA OBSERVABILITY: VIEW HỢP NHẤT TOÀN BỘ PIPELINE HEALTH (TEAM 7)
-- ==============================================================================
-- View hợp nhất các chỉ số giám sát chất lượng dữ liệu của toàn bộ Data Warehouse:
--   1. BRONZE LAYER : obs_bronze_health (Freshness, Volume, Schema Drift - 9 bảng nguồn)
--   2. SILVER LAYER : obs_silver_row_audit (Đối soát dòng ngưỡng linh hoạt - 9 model Silver)
--                     obs_invalid_records (Tổng hợp các bản ghi gắn cờ vi phạm DQ)
--   3. GOLD LAYER   : obs_gold_health (Kiểm toán tài chính IFRS 15, cước phí, dòng tiền)
--   4. MART LAYER   : mart_customer_360 (Kiểm tra bảo toàn grain khách hàng)
--
-- NGUYÊN TẮC: Đọc lại các view obs_* sẵn có, hợp nhất trạng thái mà không viết lại từ đầu.
-- ==============================================================================

WITH bronze_health AS (
    SELECT
        'BRONZE'                                                        AS pipeline_layer,
        table_name                                                      AS entity_or_check_name,
        'FRESHNESS_VOLUME_SCHEMA'                                       AS check_category,
        CAST(current_rows AS DOUBLE)                                    AS current_value,
        CAST(prev_rows AS DOUBLE)                                       AS expected_value,
        CAST(CASE WHEN prev_rows IS NOT NULL THEN current_rows - prev_rows ELSE 0 END AS DOUBLE) AS discrepancy,
        overall_health                                                  AS health_status,
        CASE WHEN overall_health = 'FAIL' THEN 'BLOCK' ELSE 'ALLOW' END AS gate_action,
        'Volume: ' || volume_status || ' (' || volume_note || ') | Freshness: ' || freshness_status || ' (' || freshness_note || ') | Schema: ' || schema_status AS audit_details,
        checked_at
    FROM {{ ref('obs_bronze_health') }}
),

silver_row_health AS (
    SELECT
        'SILVER'                                                        AS pipeline_layer,
        entity_name                                                     AS entity_or_check_name,
        'ROW_RECONCILIATION'                                            AS check_category,
        CAST(silver_row_count AS DOUBLE)                                AS current_value,
        CAST(bronze_row_count AS DOUBLE)                                AS expected_value,
        CAST(silver_row_count - bronze_row_count AS DOUBLE)             AS discrepancy,
        reconciliation_status                                           AS health_status,
        gate_action,
        audit_rule_desc || ' (Tỷ lệ: ' || CAST(row_ratio_pct AS VARCHAR) || '%, Ngưỡng: ' || CAST(min_threshold_pct AS VARCHAR) || '% - ' || CAST(max_threshold_pct AS VARCHAR) || '%)' AS audit_details,
        CURRENT_TIMESTAMP                                               AS checked_at
    FROM {{ ref('obs_silver_row_audit') }}
),

silver_dq_health AS (
    SELECT
        'SILVER'                                                        AS pipeline_layer,
        'dq_flags_' || flag_name                                        AS entity_or_check_name,
        'DATA_QUALITY_AUDIT'                                            AS check_category,
        CAST(COUNT(*) AS DOUBLE)                                        AS current_value,
        0.0                                                             AS expected_value,
        CAST(COUNT(*) AS DOUBLE)                                        AS discrepancy,
        'WARN'                                                          AS health_status,
        'ALLOW'                                                         AS gate_action,
        'Ghi nhận ' || CAST(COUNT(*) AS VARCHAR) || ' dòng gắn cờ vi phạm: ' || MAX(audit_issue_desc) || ' (Không loại bỏ dòng thô)' AS audit_details,
        CURRENT_TIMESTAMP                                               AS checked_at
    FROM {{ ref('obs_invalid_records') }}
    GROUP BY flag_name
),

gold_health AS (
    SELECT
        'GOLD'                                                          AS pipeline_layer,
        audit_check_name                                                AS entity_or_check_name,
        audit_category                                                  AS check_category,
        current_value,
        expected_value,
        discrepancy,
        audit_status                                                    AS health_status,
        gate_action,
        audit_rule_desc                                                 AS audit_details,
        checked_at
    FROM {{ ref('obs_gold_health') }}
),

mart_health AS (
    SELECT
        'MART'                                                          AS pipeline_layer,
        'mart_customer_360'                                             AS entity_or_check_name,
        'CUSTOMER_360_GRAIN'                                            AS check_category,
        CAST(COUNT(*) AS DOUBLE)                                        AS current_value,
        CAST(COUNT(DISTINCT customer_unique_id) AS DOUBLE)              AS expected_value,
        0.0                                                             AS discrepancy,
        CASE 
            WHEN COUNT(*) = COUNT(DISTINCT customer_unique_id) AND COUNT(*) > 0 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END                                                             AS health_status,
        CASE 
            WHEN COUNT(*) = COUNT(DISTINCT customer_unique_id) AND COUNT(*) > 0 
            THEN 'ALLOW' 
            ELSE 'BLOCK' 
        END                                                             AS gate_action,
        'Hồ sơ Customer 360 bảo toàn grain 1 dòng/khách (' || CAST(COUNT(*) AS VARCHAR) || ' khách hàng delivered)' AS audit_details,
        CURRENT_TIMESTAMP                                               AS checked_at
    FROM {{ ref('mart_customer_360') }}
),

unified_observability AS (
    SELECT * FROM bronze_health
    UNION ALL
    SELECT * FROM silver_row_health
    UNION ALL
    SELECT * FROM silver_dq_health
    UNION ALL
    SELECT * FROM gold_health
    UNION ALL
    SELECT * FROM mart_health
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY 
            CASE pipeline_layer
                WHEN 'BRONZE' THEN 1
                WHEN 'SILVER' THEN 2
                WHEN 'GOLD'   THEN 3
                WHEN 'MART'   THEN 4
                ELSE 5
            END,
            entity_or_check_name
    ) AS obs_id,
    pipeline_layer,
    entity_or_check_name,
    check_category,
    current_value,
    expected_value,
    discrepancy,
    health_status,
    gate_action,
    audit_details,
    checked_at
FROM unified_observability
ORDER BY obs_id
