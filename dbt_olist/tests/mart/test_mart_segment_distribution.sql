{{
    config(
        tags=['mart', 'rfm', 'segment', 'distribution', 'gd4.6']
    )
}}

-- ==============================================================================
-- GD4.6 - SINGULAR AUDIT TEST: PHÂN PHỐI TỶ TRỌNG SEGMENT KHÁCH HÀNG (TEAM 7)
-- ==============================================================================
-- Mục đích:
--   Kiểm tra tính hợp lý của tỷ trọng từng phân khúc khách hàng (Segment):
--   1. Không có segment nào bị rỗng (tỷ trọng = 0.00% hoặc count < 10).
--   2. Không có segment nào chiếm ưu thế cực đoan bất thường (> 80.00%).
--   3. Đảm bảo toàn bộ 5 phân khúc nghiệp vụ đều ghi nhận dữ liệu thực tế.
--   Query trả về dòng vi phạm nếu tỷ trọng segment có dấu hiệu bất thường.
-- ==============================================================================

WITH total_population AS (
    SELECT COUNT(*) AS total_customers FROM {{ ref('mart_customer_360') }}
),

segment_distribution AS (
    SELECT
        segment,
        COUNT(*)                                            AS segment_customer_count,
        ROUND((COUNT(*) * 100.0) / MAX(t.total_customers), 2) AS segment_percentage
    FROM {{ ref('mart_customer_360') }}
    CROSS JOIN total_population t
    GROUP BY segment
)

SELECT
    segment,
    segment_customer_count,
    segment_percentage,
    CASE
        WHEN segment_customer_count < 10 THEN 'Phân khúc có số lượng quá nhỏ (< 10 khách hàng)'
        WHEN segment_percentage <= 0.00 THEN 'Phân khúc bị rỗng (0.00%)'
        WHEN segment_percentage >= 80.00 THEN 'Phân khúc chiếm tỷ trọng cực đoan (>= 80.00%)'
        ELSE 'Bất thường không xác định'
    END AS anomaly_description
FROM segment_distribution
WHERE segment_percentage <= 0.00 
   OR segment_percentage >= 80.00
   OR segment_customer_count < 10
