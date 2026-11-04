{{
    config(
        materialized='table',
        schema='mart',
        tags=['mart', 'customer', 'customer_cluster', 'gd4.12']
    )
}}

-- ==============================================================================
-- GD4.12 - BẢNG CHIỀU PHÂN CỤM KHÁCH HÀNG (dim_customer_cluster)
-- ==============================================================================
-- Grain      : 1 dòng / cluster_id
-- Khóa chính : cluster_id (INTEGER); -1 = khách chưa có kết quả phân cụm
-- Nguồn      : source ml.cluster_profile, do notebooks/04_ml_clustering.ipynb ghi ra
--              (K-Means trên recency_days, frequency, monetary của mart_customer_rfm).
--              Nhãn và mô tả cụm do notebook sinh theo luật từ chân dung cụm, không gõ tay,
--              nên bảng luôn khớp với lần chạy mô hình gần nhất.
-- ==============================================================================

WITH profile AS (
    SELECT
        CAST(cluster_id AS INTEGER)               AS cluster_id,
        CAST(cluster_label AS VARCHAR)            AS cluster_label,
        CAST(cluster_description AS VARCHAR)      AS cluster_description,
        CAST(n_customers AS INTEGER)              AS n_customers,
        CAST(pct_customers AS DECIMAL(5, 2))      AS pct_customers,
        CAST(sum_monetary AS DECIMAL(12, 2))      AS sum_monetary,
        CAST(pct_monetary AS DECIMAL(5, 2))       AS pct_monetary,
        CAST(median_recency_days AS DOUBLE)       AS median_recency_days,
        CAST(mean_frequency AS DOUBLE)            AS mean_frequency,
        CAST(repeat_rate AS DOUBLE)               AS repeat_rate,
        CAST(median_monetary AS DECIMAL(10, 2))   AS median_monetary,
        CAST(mean_monetary AS DOUBLE)             AS mean_monetary,
        CAST(avg_review_score AS DOUBLE)          AS avg_review_score,
        CAST(late_order_rate AS DOUBLE)           AS late_order_rate,
        CAST(top_state AS VARCHAR)                AS top_state,
        CAST(k AS INTEGER)                        AS k,
        CAST(feature_set_version AS VARCHAR)      AS feature_set_version,
        CAST(model_run_ts AS TIMESTAMP)           AS model_run_ts
    FROM {{ source('ml', 'cluster_profile') }}
),

unassigned AS (
    SELECT
        -1                                        AS cluster_id,
        'Chưa phân cụm'                           AS cluster_label,
        'Khách chưa có kết quả phân cụm K-Means (bản ghi -1 bảo toàn toàn vẹn khóa ngoại).' AS cluster_description,
        0                                         AS n_customers,
        CAST(0 AS DECIMAL(5, 2))                  AS pct_customers,
        CAST(0 AS DECIMAL(12, 2))                 AS sum_monetary,
        CAST(0 AS DECIMAL(5, 2))                  AS pct_monetary,
        CAST(NULL AS DOUBLE)                      AS median_recency_days,
        CAST(NULL AS DOUBLE)                      AS mean_frequency,
        CAST(NULL AS DOUBLE)                      AS repeat_rate,
        CAST(NULL AS DECIMAL(10, 2))              AS median_monetary,
        CAST(NULL AS DOUBLE)                      AS mean_monetary,
        CAST(NULL AS DOUBLE)                      AS avg_review_score,
        CAST(NULL AS DOUBLE)                      AS late_order_rate,
        'N/A'                                     AS top_state,
        CAST(NULL AS INTEGER)                     AS k,
        CAST(NULL AS VARCHAR)                     AS feature_set_version,
        CAST(NULL AS TIMESTAMP)                   AS model_run_ts
)

SELECT *, CURRENT_TIMESTAMP AS dbt_created_at FROM profile
UNION ALL
SELECT *, CURRENT_TIMESTAMP AS dbt_created_at FROM unassigned
ORDER BY cluster_id
