{{
    config(
        materialized='table',
        schema='mart',
        tags=['mart', 'customer', 'customer_cluster', 'gd4.12']
    )
}}

-- ==============================================================================
-- GD4.12 - XÂY DỰNG BẢNG CHIỀU PHÂN CỤM KHÁCH HÀNG (dim_customer_cluster)
-- ==============================================================================
-- Căn cứ thiết kế: [DW] GD4.1 Customer Data Mart Design (Mục 3.2 & Sơ đồ Data Mart)
-- Nguồn dữ liệu: Kết quả phân cụm K-Means tối ưu (K=3) từ notebooks/04_ml_clustering.ipynb
-- Grain: 1 dòng / cluster_id (1 dòng đại diện cho 1 cụm phân khúc khách hàng)
-- Khóa chính: cluster_id (INTEGER)
-- ==============================================================================

WITH cluster_definitions AS (
    -- Cụm 1: Khách hàng chi tiêu cao, không hài lòng / Nguy cơ rời bỏ do vận chuyển
    SELECT
        1 AS cluster_id,
        'C1 · Lâu rồi · Chi cao · Không hài lòng' AS cluster_label,
        'Khách hàng chi tiêu cao (median GMV 125.87 BRL, mean 197.62 BRL), đã lâu không mua hàng (median Recency 218 ngày), đánh giá trải nghiệm dịch vụ rất thấp (review TB 1.94 sao) do thời gian giao hàng dài (median 21 ngày) và tỷ lệ đơn trễ hạn cao (38.65%). Chiếm 16.63% tổng số khách hàng và đóng góp 19.89% tổng GMV toàn sàn.' AS cluster_description,
        15523 AS n_customers,
        16.63 AS pct_customers,
        3067611.60 AS sum_gmv,
        19.89 AS pct_gmv,
        218.0 AS median_recency_days,
        125.87 AS median_total_gmv,
        197.62 AS mean_total_gmv,
        1.94 AS avg_review_score,
        21.0 AS median_lead_time_days,
        0.3865 AS late_order_rate,
        'SP' AS top_state

    UNION ALL

    -- Cụm 2: Khách hàng cũ phổ thông, chi tiêu thấp nhưng rất hài lòng
    SELECT
        2 AS cluster_id,
        'C2 · Lâu rồi · Chi thấp · Hài lòng' AS cluster_label,
        'Khách hàng mua hàng từ lâu (median Recency 278 ngày), chi tiêu mức trung bình thấp (median GMV 107.02 BRL), nhưng có trải nghiệm giao vận và dịch vụ rất tốt (review TB 4.63 sao, giao sớm 14.15 ngày, tỷ lệ trễ chỉ 1.76%). Chiếm tỷ trọng lớn nhất với 60.72% khách hàng và 59.98% tổng GMV toàn sàn.' AS cluster_description,
        56690 AS n_customers,
        60.72 AS pct_customers,
        9248487.09 AS sum_gmv,
        59.98 AS pct_gmv,
        278.0 AS median_recency_days,
        107.02 AS median_total_gmv,
        163.14 AS mean_total_gmv,
        4.63 AS avg_review_score,
        11.0 AS median_lead_time_days,
        0.0176 AS late_order_rate,
        'SP' AS top_state

    UNION ALL

    -- Cụm 3: Khách hàng mới / hoạt động gần đây, hài lòng cao
    SELECT
        3 AS cluster_id,
        'C3 · Gần đây · Chi thấp · Hài lòng' AS cluster_label,
        'Khách hàng mới mua hàng gần đây (median Recency 54 ngày), giá trị đơn hàng mức vừa phải (median GMV 97.43 BRL), mức độ hài lòng rất cao (review TB 4.51 sao, giao hàng cực nhanh với lead time 6 ngày, giao sớm 12.75 ngày, tỷ lệ trễ 2.81%). Phân bố tập trung lớn tại bang São Paulo (56.36%). Chiếm 22.65% khách hàng và đóng góp 20.13% tổng GMV toàn sàn.' AS cluster_description,
        21145 AS n_customers,
        22.65 AS pct_customers,
        3103675.06 AS sum_gmv,
        20.13 AS pct_gmv,
        54.0 AS median_recency_days,
        97.43 AS median_total_gmv,
        146.78 AS mean_total_gmv,
        4.51 AS avg_review_score,
        6.0 AS median_lead_time_days,
        0.0281 AS late_order_rate,
        'SP' AS top_state

    UNION ALL

    -- Bản ghi giả lập Sentinel (-1) bảo vệ toàn vẹn tham chiếu khóa ngoại
    SELECT
        -1 AS cluster_id,
        'Chưa phân cụm (Unassigned)' AS cluster_label,
        'Bản ghi giả lập Sentinel (-1) đại diện cho khách hàng chưa đủ điều kiện phân cụm (chưa có đơn delivered) hoặc chưa chạy qua pipeline K-Means, bảo vệ toàn vẹn tham chiếu khóa ngoại.' AS cluster_description,
        0 AS n_customers,
        0.00 AS pct_customers,
        0.00 AS sum_gmv,
        0.00 AS pct_gmv,
        NULL AS median_recency_days,
        NULL AS median_total_gmv,
        NULL AS mean_total_gmv,
        NULL AS avg_review_score,
        NULL AS median_lead_time_days,
        NULL AS late_order_rate,
        'N/A' AS top_state
)

SELECT
    cluster_id,
    cluster_label,
    cluster_description,
    n_customers,
    pct_customers,
    sum_gmv,
    pct_gmv,
    median_recency_days,
    median_total_gmv,
    mean_total_gmv,
    avg_review_score,
    median_lead_time_days,
    late_order_rate,
    top_state,
    CURRENT_TIMESTAMP AS dbt_created_at
FROM cluster_definitions
ORDER BY cluster_id ASC

