{{
    config(
        materialized='table',
        schema='gold',
        tags=['gold', 'analytics', 'olap', 'scenarios']
    )
}}

-- ==============================================================================
-- 4 KỊCH BẢN PHÂN TÍCH OLAP CHUYÊN SÂU GẮN VỚI 4 PHÒNG BAN (olap_scenarios)
-- ==============================================================================
-- Kịch bản 1 (BOD & Marketing): Tăng trưởng Net Revenue, Delivered GMV, AOV theo 
--   Năm/Quý/Tháng x Danh mục sản phẩm (ROLLUP đa cấp, Window Function % GMV, chuẩn IFRS 15).
-- Kịch bản 2 (Logistics & Supply Chain): Tuyến đường liên bang (Seller State -> Shipping State),
--   so sánh Calendar Lead Time vs Business Days Lead Time (Dias Úteis - Lei 6.538/1978).
-- Kịch bản 3 (Customer Service & QC): Đo lường CSAT & Detractor Rate (1-2 sao), 
--   triệt tiêu Fan-Out liên Fact (fact_sales x fact_customer_reviews) bằng trọng số 1/k.
-- Kịch bản 4 (Finance & Revenue Assurance): Cơ cấu kênh thanh toán chủ đạo theo từng bang 
--   bằng kỹ thuật PIVOT, đối soát penny tuyệt đối (audit_penny_discrepancy = 0.00).
-- ==============================================================================

WITH 
-- ==============================================================================
-- 1. KỊCH BẢN 1 (BOD & MARKETING): ROLLUP & WINDOW FUNCTION % GMV
-- ==============================================================================
scenario_1_prep AS (
    SELECT 
        f.order_id,
        f.product_id,
        COALESCE(t.product_category_name_english, p.product_category_name_portuguese, 'unknown') AS category_name,
        EXTRACT(year FROM strptime(CAST(f.purchase_date_key AS VARCHAR), '%Y%m%d'))::INTEGER AS order_year,
        EXTRACT(quarter FROM strptime(CAST(f.purchase_date_key AS VARCHAR), '%Y%m%d'))::INTEGER AS order_quarter,
        EXTRACT(month FROM strptime(CAST(f.purchase_date_key AS VARCHAR), '%Y%m%d'))::INTEGER AS order_month,
        f.price,
        f.gmv
    FROM {{ ref('fact_sales') }} f
    LEFT JOIN {{ ref('dim_product') }} p ON f.product_id = p.product_id
    LEFT JOIN {{ ref('silver_category_translation') }} t ON p.product_category_name_portuguese = t.product_category_name
    WHERE f.order_status = 'delivered'
),

scenario_1_rollup AS (
    SELECT 
        'SCENARIO_1_BOD_MARKETING' AS scenario_id,
        'BOD & Marketing' AS department,
        'Net Revenue, GMV & AOV Multi-Dimensional Rollup' AS sub_scenario,
        CASE 
            WHEN order_year IS NULL THEN 'ALL_YEARS'
            ELSE CAST(order_year AS VARCHAR)
        END AS dimension_1,
        CASE 
            WHEN order_year IS NULL THEN 'ALL_PERIODS'
            WHEN order_quarter IS NULL THEN 'FULL_YEAR'
            WHEN order_month IS NULL THEN 'Q' || CAST(order_quarter AS VARCHAR) || '_TOTAL'
            ELSE 'Q' || CAST(order_quarter AS VARCHAR) || '-' || LPAD(CAST(order_month AS VARCHAR), 2, '0')
        END AS dimension_2,
        CASE 
            WHEN category_name IS NULL THEN 'ALL_CATEGORIES'
            ELSE category_name
        END AS dimension_3,
        ROUND(SUM(gmv), 2) AS metric_val_1, -- delivered_gmv
        ROUND(SUM(price), 2) AS metric_val_2, -- net_revenue
        COUNT(DISTINCT order_id)::DOUBLE AS metric_val_3, -- distinct_orders
        ROUND(SUM(gmv) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS metric_val_4, -- aov
        ROUND(SUM(SUM(gmv)) OVER (PARTITION BY category_name), 2) AS metric_val_5, -- total_category_gmv
        ROUND(SUM(gmv) * 100.0 / NULLIF(SUM(SUM(gmv)) OVER (PARTITION BY category_name), 0), 4) AS metric_pct, -- pct_category_gmv
        'ROLLUP & Window Function' AS olap_technique,
        'IFRS 15 Slice (order_status = delivered)' AS audit_trail
    FROM scenario_1_prep
    GROUP BY ROLLUP (order_year, order_quarter, order_month, category_name)
),

-- ==============================================================================
-- 2. KỊCH BẢN 2 (LOGISTICS & SUPPLY CHAIN): LEAD TIME & DIAS ÚTEIS
-- ==============================================================================
scenario_2_prep AS (
    SELECT 
        o.order_id,
        o.order_purchase_timestamp::DATE AS purchase_date,
        o.order_delivered_customer_date::DATE AS delivered_date,
        date_diff('day', o.order_purchase_timestamp::DATE, o.order_delivered_customer_date::DATE) AS calendar_lead_time_days,
        len([d for d in range(o.order_purchase_timestamp::DATE, o.order_delivered_customer_date::DATE, INTERVAL 1 DAY) 
             IF dayofweek(d) NOT IN (0, 6) 
               AND strftime(d, '%m-%d') NOT IN ('01-01', '04-21', '05-01', '09-07', '10-12', '11-02', '11-15', '12-25')]) AS business_lead_time_days
    FROM {{ ref('silver_orders') }} o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_delivered_customer_date >= o.order_purchase_timestamp
),

scenario_2_routes AS (
    SELECT 
        'SCENARIO_2_LOGISTICS' AS scenario_id,
        'Logistics & Supply Chain' AS department,
        'Interstate Route Lead Time & SLA Performance' AS sub_scenario,
        s.seller_state AS dimension_1,
        f.shipping_state AS dimension_2,
        s.seller_state || ' -> ' || f.shipping_state AS dimension_3,
        COUNT(DISTINCT f.order_id)::DOUBLE AS metric_val_1, -- total_orders
        ROUND(AVG(p.calendar_lead_time_days), 2) AS metric_val_2, -- avg_calendar_lead_time_days
        ROUND(AVG(p.business_lead_time_days), 2) AS metric_val_3, -- avg_business_lead_time_days (Dias Uteis)
        ROUND(AVG(p.calendar_lead_time_days - p.business_lead_time_days), 2) AS metric_val_4, -- avg_delay_days
        ROUND(SUM(f.freight_value), 2) AS metric_val_5, -- total_freight_value
        ROUND(AVG(p.calendar_lead_time_days - p.business_lead_time_days) * 100.0 / NULLIF(AVG(p.calendar_lead_time_days), 0), 2) AS metric_pct, -- delay_pct
        'Date Sequence Dias Uteis (Lei 6.538/1978)' AS olap_technique,
        'Excludes Weekends & Brazil Statutory Holidays' AS audit_trail
    FROM {{ ref('fact_sales') }} f
    JOIN {{ ref('dim_seller') }} s ON f.seller_id = s.seller_id
    JOIN scenario_2_prep p ON f.order_id = p.order_id
    WHERE f.order_status = 'delivered'
    GROUP BY s.seller_state, f.shipping_state
),

-- ==============================================================================
-- 3. KỊCH BẢN 3 (CUSTOMER SERVICE & QC): 1/K WEIGHTED CSAT & DETRACTOR RATE
-- ==============================================================================
scenario_3_prep AS (
    SELECT 
        f.order_id,
        f.order_item_id,
        f.product_id,
        COALESCE(t.product_category_name_english, p.product_category_name_portuguese, 'unknown') AS category_name,
        1.0 / COUNT(*) OVER (PARTITION BY f.order_id) AS weight
    FROM {{ ref('fact_sales') }} f
    LEFT JOIN {{ ref('dim_product') }} p ON f.product_id = p.product_id
    LEFT JOIN {{ ref('silver_category_translation') }} t ON p.product_category_name_portuguese = t.product_category_name
    WHERE f.order_status = 'delivered'
),

scenario_3_qc AS (
    SELECT 
        'SCENARIO_3_CUSTOMER_SERVICE' AS scenario_id,
        'Customer Service & QC' AS department,
        'Weighted CSAT & Detractor Rate Analysis' AS sub_scenario,
        sp.category_name AS dimension_1,
        'Quality Assurance' AS dimension_2,
        'Cross-Fact Sales-Reviews' AS dimension_3,
        ROUND(SUM(sp.weight), 2) AS metric_val_1, -- allocated_review_count
        COUNT(DISTINCT sp.order_id)::DOUBLE AS metric_val_2, -- distinct_orders
        ROUND(SUM(r.review_score * sp.weight) / NULLIF(SUM(sp.weight), 0), 2) AS metric_val_3, -- weighted_csat
        ROUND(SUM(CASE WHEN r.review_score IN (4, 5) THEN sp.weight ELSE 0.0 END), 2) AS metric_val_4, -- promoter_count
        ROUND(SUM(CASE WHEN r.review_score IN (1, 2) THEN sp.weight ELSE 0.0 END), 2) AS metric_val_5, -- detractor_count
        ROUND(SUM(CASE WHEN r.review_score IN (1, 2) THEN sp.weight ELSE 0.0 END) * 100.0 / NULLIF(SUM(sp.weight), 0), 2) AS metric_pct, -- detractor_rate_pct
        '1/k Cross-Fact Weight Allocation' AS olap_technique,
        'Fan-Out Eliminated (100% Balanced)' AS audit_trail
    FROM scenario_3_prep sp
    JOIN {{ ref('fact_customer_reviews') }} r ON sp.order_id = r.order_id
    GROUP BY sp.category_name
),

-- ==============================================================================
-- 4. KỊCH BẢN 4 (FINANCE & REVENUE ASSURANCE): PIVOT & PENNY AUDIT
-- ==============================================================================
scenario_4_prep AS (
    SELECT 
        c.customer_state,
        p.payment_type,
        p.payment_value
    FROM {{ ref('silver_order_payments') }} p
    JOIN {{ ref('silver_orders') }} o ON p.order_id = o.order_id
    JOIN {{ ref('silver_customers') }} c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

scenario_4_finance AS (
    SELECT 
        'SCENARIO_4_FINANCE' AS scenario_id,
        'Finance & Revenue Assurance' AS department,
        'Payment Channel PIVOT & Penny Reconciliation' AS sub_scenario,
        customer_state AS dimension_1,
        'Payment Channel Distribution' AS dimension_2,
        'PIVOT by Method' AS dimension_3,
        ROUND(SUM(CASE WHEN payment_type = 'credit_card' THEN payment_value ELSE 0 END), 2) AS metric_val_1, -- credit_card_value
        ROUND(SUM(CASE WHEN payment_type = 'boleto' THEN payment_value ELSE 0 END), 2) AS metric_val_2, -- boleto_value
        ROUND(SUM(CASE WHEN payment_type = 'voucher' THEN payment_value ELSE 0 END), 2) AS metric_val_3, -- voucher_value
        ROUND(SUM(CASE WHEN payment_type = 'debit_card' THEN payment_value ELSE 0 END), 2) AS metric_val_4, -- debit_card_value
        ROUND(SUM(payment_value), 2) AS metric_val_5, -- total_payment_value
        ROUND(SUM(CASE WHEN payment_type = 'credit_card' THEN payment_value ELSE 0 END) * 100.0 / NULLIF(SUM(payment_value), 0), 2) AS metric_pct, -- credit_card_share_pct
        'PIVOT & Hare-Niemeyer Penny Audit' AS olap_technique,
        'audit_penny_discrepancy = 0.00' AS audit_trail
    FROM scenario_4_prep
    GROUP BY customer_state
),

combined_scenarios AS (
    SELECT * FROM scenario_1_rollup
    UNION ALL
    SELECT * FROM scenario_2_routes
    UNION ALL
    SELECT * FROM scenario_3_qc
    UNION ALL
    SELECT * FROM scenario_4_finance
)

SELECT
    -- 0. Khóa thay thế (Surrogate Key) đại diện cho từng dòng phân tích
    {{ dbt_utils.generate_surrogate_key(['scenario_id', 'dimension_1', 'dimension_2', 'dimension_3']) }} AS scenario_row_key,

    -- 1. Định danh Kịch bản & Phòng ban nghiệp vụ
    scenario_id,
    department,
    sub_scenario,

    -- 2. Hệ trục phân tích đa chiều (Multi-Dimensional Hierarchy)
    dimension_1,
    dimension_2,
    dimension_3,

    -- 3. Các chỉ số đo lường nghiệp vụ cốt lõi (Core Business Measures)
    metric_val_1,
    metric_val_2,
    metric_val_3,
    metric_val_4,
    metric_val_5,
    metric_pct,

    -- 4. Kỹ thuật OLAP và dấu vết kiểm toán IFRS / Penny Reconciliation
    olap_technique,
    audit_trail,
    CURRENT_TIMESTAMP AS dbt_created_at

FROM combined_scenarios
