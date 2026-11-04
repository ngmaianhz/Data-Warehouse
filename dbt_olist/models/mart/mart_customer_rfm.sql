{{
    config(
        materialized='table',
        schema='mart',
        tags=['mart', 'customer', 'customer_cluster', 'gd4.12']
    )
}}

-- ==============================================================================
-- GD4.12 - MART CUSTOMER RFM (đầu vào và kết quả K-Means)
-- ==============================================================================
-- Grain     : 1 dòng / customer_unique_id có ít nhất 1 đơn delivered
-- Phụ thuộc : mart_customer_360 (đã lọc đơn delivered), source ml.customer_cluster
-- Vai trò   : (1) 3 đặc trưng đầu vào K-Means: recency_days, frequency, monetary
--             (2) gán khách vào cụm K-Means qua cluster_id (FK -> dim_customer_cluster)
-- Nhóm đã bỏ chấm điểm RFM (r/f/m_score, segment); phân khúc khách dùng cụm K-Means.
--
-- Thứ tự chạy: build model này (cluster_id lấy theo lần chạy K-Means trước, hoặc -1)
--              -> chạy notebooks/04_ml_clustering.ipynb (ghi ml.customer_cluster)
--              -> build lại model này để lấy cluster_id mới.
-- ==============================================================================

WITH rfm AS (
    SELECT
        customer_unique_id,
        -- Recency: số ngày từ đơn delivered cuối cùng đến ngày mua delivered gần nhất toàn hệ thống
        CAST(date_diff('day', last_order_date, MAX(last_order_date) OVER ()) AS INTEGER) AS recency_days,
        -- Frequency: số đơn delivered
        CAST(total_orders AS INTEGER)                                                     AS frequency,
        -- Monetary: tổng GMV các đơn delivered (BRL)
        CAST(total_gmv AS DECIMAL(10, 2))                                                 AS monetary
    FROM {{ ref('mart_customer_360') }}
)

SELECT
    r.customer_unique_id,
    r.recency_days,
    r.frequency,
    r.monetary,
    -- Khách chưa có kết quả phân cụm nhận -1
    CAST(COALESCE(c.cluster_id, -1) AS INTEGER) AS cluster_id,
    CURRENT_TIMESTAMP                           AS dbt_created_at
FROM rfm r
LEFT JOIN {{ source('ml', 'customer_cluster') }} c
    ON r.customer_unique_id = c.customer_unique_id
