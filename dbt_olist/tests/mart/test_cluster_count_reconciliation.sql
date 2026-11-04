{{ config(tags=['mart', 'customer_cluster', 'gd4.12']) }}

-- ==============================================================================
-- GD4.12 - Đối soát số khách theo cụm giữa mart_customer_rfm và dim_customer_cluster
-- ==============================================================================
-- Trả về dòng vi phạm khi:
--   1. số khách của một cụm trong mart_customer_rfm khác n_customers trong dim_customer_cluster, hoặc
--   2. còn khách mang cluster_id = -1 (chưa được gán cụm sau khi chạy K-Means).
-- ==============================================================================

WITH rfm AS (
    SELECT cluster_id, COUNT(*) AS n_rfm
    FROM {{ ref('mart_customer_rfm') }}
    GROUP BY cluster_id
),

dim AS (
    SELECT cluster_id, n_customers AS n_dim
    FROM {{ ref('dim_customer_cluster') }}
    WHERE cluster_id <> -1
)

SELECT
    COALESCE(rfm.cluster_id, dim.cluster_id) AS cluster_id,
    rfm.n_rfm,
    dim.n_dim,
    CASE
        WHEN COALESCE(rfm.cluster_id, dim.cluster_id) = -1 THEN 'Còn khách chưa được gán cụm'
        ELSE 'Số khách theo cụm không khớp giữa mart_customer_rfm và dim_customer_cluster'
    END AS failure_reason
FROM rfm
FULL OUTER JOIN dim ON rfm.cluster_id = dim.cluster_id
WHERE COALESCE(rfm.cluster_id, dim.cluster_id) = -1
   OR COALESCE(rfm.n_rfm, 0) <> COALESCE(dim.n_dim, 0)
