{{
    config(
        materialized='view',
        schema='gold',
        tags=['gold', 'observability', 'audit', 'gd4.6']
    )
}}

-- ==============================================================================
-- GD4.6 - OBSERVABILITY BASELINE CHO GOLD LAYER (Team 7)
-- ==============================================================================
-- View đối soát kiểm toán tài chính và bảo toàn số dòng tầng Gold:
--   1. ROW_COUNT       : Bảo toàn 112,650 dòng fact_sales = silver_order_items
--   2. NET_REVENUE     : IFRS 15 Doanh thu thuần SUM(price) khớp tuyệt đối
--   3. FREIGHT_VALUE   : Cước phí vận chuyển SUM(freight_value) khớp tuyệt đối
--   4. PENNY_CASH_FLOW : Dòng tiền phân bổ Hare-Niemeyer khớp từng cent
-- ==============================================================================

WITH fact_summary AS (
    SELECT
        COUNT(*)                                                AS fact_sales_rows,
        CAST(ROUND(SUM(price), 2) AS DECIMAL(12, 2))           AS fact_total_price,
        CAST(ROUND(SUM(freight_value), 2) AS DECIMAL(12, 2))   AS fact_total_freight,
        CAST(ROUND(SUM(allocated_payment_value), 2) AS DECIMAL(12, 2)) AS fact_allocated_payment
    FROM {{ ref('fact_sales') }}
),

silver_items_summary AS (
    SELECT
        COUNT(*)                                                AS silver_items_rows,
        CAST(ROUND(SUM(price), 2) AS DECIMAL(12, 2))           AS silver_total_price,
        CAST(ROUND(SUM(freight_value), 2) AS DECIMAL(12, 2))   AS silver_total_freight
    FROM {{ ref('silver_order_items') }}
),

silver_payments_summary AS (
    SELECT
        CAST(ROUND(SUM(p.payment_value), 2) AS DECIMAL(12, 2)) AS silver_total_matched_payment
    FROM {{ ref('silver_order_payments') }} p
    WHERE p.order_id IN (SELECT DISTINCT order_id FROM {{ ref('fact_sales') }})
),

audit_metrics AS (
    -- 1. Row count
    SELECT
        1 AS stt,
        'fact_sales_row_count' AS audit_check_name,
        'ROW_COUNT_INTEGRITY' AS audit_category,
        CAST(f.fact_sales_rows AS DOUBLE) AS current_value,
        CAST(s.silver_items_rows AS DOUBLE) AS expected_value,
        CAST(f.fact_sales_rows - s.silver_items_rows AS DOUBLE) AS discrepancy,
        CASE 
            WHEN f.fact_sales_rows = s.silver_items_rows AND f.fact_sales_rows = 112650 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END AS audit_status,
        CASE 
            WHEN f.fact_sales_rows = s.silver_items_rows AND f.fact_sales_rows = 112650 
            THEN 'ALLOW' 
            ELSE 'BLOCK' 
        END AS gate_action,
        'Bảo toàn 100% số dòng chi tiết bán hàng (112,650 dòng)' AS audit_rule_desc
    FROM fact_summary f, silver_items_summary s

    UNION ALL

    -- 2. Net revenue
    SELECT
        2 AS stt,
        'net_revenue_ifrs15' AS audit_check_name,
        'FINANCIAL_REVENUE' AS audit_category,
        CAST(f.fact_total_price AS DOUBLE) AS current_value,
        CAST(s.silver_total_price AS DOUBLE) AS expected_value,
        CAST(ROUND(f.fact_total_price - s.silver_total_price, 2) AS DOUBLE) AS discrepancy,
        CASE 
            WHEN f.fact_total_price = s.silver_total_price 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END AS audit_status,
        CASE 
            WHEN f.fact_total_price = s.silver_total_price 
            THEN 'ALLOW' 
            ELSE 'BLOCK' 
        END AS gate_action,
        'Đối soát doanh thu thuần chuẩn IFRS 15 (Chính xác tuyệt đối 0.00)' AS audit_rule_desc
    FROM fact_summary f, silver_items_summary s

    UNION ALL

    -- 3. Freight value
    SELECT
        3 AS stt,
        'freight_value_reconcile' AS audit_check_name,
        'FINANCIAL_FREIGHT' AS audit_category,
        CAST(f.fact_total_freight AS DOUBLE) AS current_value,
        CAST(s.silver_total_freight AS DOUBLE) AS expected_value,
        CAST(ROUND(f.fact_total_freight - s.silver_total_freight, 2) AS DOUBLE) AS discrepancy,
        CASE 
            WHEN f.fact_total_freight = s.silver_total_freight 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END AS audit_status,
        CASE 
            WHEN f.fact_total_freight = s.silver_total_freight 
            THEN 'ALLOW' 
            ELSE 'BLOCK' 
        END AS gate_action,
        'Đối soát cước vận chuyển giữa Fact Sales và Silver Items (Khớp 0.00)' AS audit_rule_desc
    FROM fact_summary f, silver_items_summary s

    UNION ALL

    -- 4. Penny cash flow
    SELECT
        4 AS stt,
        'hare_niemeyer_penny_cash' AS audit_check_name,
        'FINANCIAL_CASH_FLOW' AS audit_category,
        CAST(f.fact_allocated_payment AS DOUBLE) AS current_value,
        CAST(p.silver_total_matched_payment AS DOUBLE) AS expected_value,
        CAST(ROUND(f.fact_allocated_payment - p.silver_total_matched_payment, 2) AS DOUBLE) AS discrepancy,
        CASE 
            WHEN f.fact_allocated_payment = p.silver_total_matched_payment 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END AS audit_status,
        CASE 
            WHEN f.fact_allocated_payment = p.silver_total_matched_payment 
            THEN 'ALLOW' 
            ELSE 'BLOCK' 
        END AS gate_action,
        'Khớp dòng tiền thực thu phân bổ từng cent theo thuật toán Hare-Niemeyer' AS audit_rule_desc
    FROM fact_summary f, silver_payments_summary p
)

SELECT
    stt,
    audit_check_name,
    audit_category,
    current_value,
    expected_value,
    discrepancy,
    audit_status,
    gate_action,
    audit_rule_desc,
    CURRENT_TIMESTAMP AS checked_at
FROM audit_metrics
ORDER BY stt
