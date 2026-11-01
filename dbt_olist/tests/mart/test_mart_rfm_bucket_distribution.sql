{{
    config(
        tags=['mart', 'rfm', 'distribution', 'gd4.6']
    )
}}

-- ==============================================================================
-- GD4.6 - SINGULAR AUDIT TEST: PHÂN PHỐI CÁC BUCKET NTILE RFM (TEAM 7)
-- ==============================================================================
-- Mục đích:
--   Kiểm tra tính đồng đều của các bucket NTILE cho r_score và m_score.
--   Với thuật toán NTILE(5), mỗi bucket (1 đến 5) phải chiếm xấp xỉ 20% dân số.
--   Ngưỡng chấp nhận: Tỷ trọng mỗi bucket nằm trong khoảng [15.0%, 25.0%].
--   Query trả về dòng vi phạm nếu có bất kỳ bucket nào bị lệch bất thường.
-- ==============================================================================

WITH total_population AS (
    SELECT COUNT(*) AS total_customers FROM {{ ref('mart_customer_360') }}
),

r_buckets AS (
    SELECT
        'r_score'                                           AS metric_name,
        r_score                                             AS bucket_id,
        COUNT(*)                                            AS customer_count,
        ROUND((COUNT(*) * 100.0) / MAX(t.total_customers), 2) AS bucket_percentage
    FROM {{ ref('mart_customer_360') }}
    CROSS JOIN total_population t
    GROUP BY r_score
),

m_buckets AS (
    SELECT
        'm_score'                                           AS metric_name,
        m_score                                             AS bucket_id,
        COUNT(*)                                            AS customer_count,
        ROUND((COUNT(*) * 100.0) / MAX(t.total_customers), 2) AS bucket_percentage
    FROM {{ ref('mart_customer_360') }}
    CROSS JOIN total_population t
    GROUP BY m_score
),

unified_buckets AS (
    SELECT * FROM r_buckets
    UNION ALL
    SELECT * FROM m_buckets
)

SELECT
    metric_name,
    bucket_id,
    customer_count,
    bucket_percentage,
    'Tỷ trọng bucket NTILE lệch ngoài ngưỡng cho phép [15.0%, 25.0%]' AS failure_reason
FROM unified_buckets
WHERE bucket_percentage < 15.00 
   OR bucket_percentage > 25.00
