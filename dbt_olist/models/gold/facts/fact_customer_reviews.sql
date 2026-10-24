{{
    config(
        materialized='table',
        schema='gold',
        tags=['gold', 'facts', 'customer_reviews', 'reviews']
    )
}}

-- ==============================================================================
-- BẢNG FACT ĐÁNH GIÁ ĐƠN HÀNG CỦA KHÁCH HÀNG (fact_customer_reviews)
-- ==============================================================================
-- Đổi tên thống nhất: fact_customer_reviews
-- Grain: 1 dòng đại diện cho 1 lần khách hàng gửi phản hồi đánh giá cho 1 đơn hàng (1 review per order)
-- Khóa chính ghép tự nhiên: (review_id, order_id)
-- Khóa ngoại: review_creation_date_key, review_answer_date_key, customer_unique_id
-- Chiều thoái hóa (Degenerate Dimension): order_id (làm cầu nối Cross-Fact sang fact_sales)
-- Measures: review_score (1-5 sao), response_time_hours, cờ has_comment_title, has_comment_message
-- Thiết kế độc lập hoàn toàn với fact_sales để triệt tiêu lỗi nhân bản số lượt đánh giá (Fan-out)
-- ==============================================================================

WITH reviews AS (
    SELECT 
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        has_comment_message,
        review_creation_date,
        review_answer_timestamp
    FROM {{ ref('silver_order_reviews') }}
),

orders_customer AS (
    -- Lấy customer_unique_id làm Conformed Foreign Key kết nối sang dim_customer
    SELECT 
        o.order_id,
        c.customer_unique_id
    FROM {{ ref('silver_orders') }} o
    JOIN {{ ref('silver_customers') }} c 
        ON o.customer_id = c.customer_id
)

SELECT 
    -- 0. Khóa thay thế (Surrogate Key) cho bản ghi Fact
    {{ dbt_utils.generate_surrogate_key(['r.review_id', 'r.order_id']) }} AS review_key,

    -- 1. Khóa chính ghép tự nhiên & Chiều thoái hóa (Degenerate Dimension)
    r.review_id,
    r.order_id,

    -- 2. Khóa ngoại Conformed & Role-Playing Dimensions
    CAST(strftime(r.review_creation_date, '%Y%m%d') AS INTEGER) AS review_creation_date_key,
    CASE 
        WHEN r.review_answer_timestamp IS NOT NULL 
        THEN CAST(strftime(r.review_answer_timestamp, '%Y%m%d') AS INTEGER) 
        ELSE -1 
    END AS review_answer_date_key,
    COALESCE(oc.customer_unique_id, 'unknown') AS customer_unique_id,

    -- 3. Số đo phân tích (Measures)
    r.review_score,
    ROUND(date_diff('second', r.review_creation_date, r.review_answer_timestamp) / 3600.0, 2) AS response_time_hours,

    -- 4. Cờ phân tích chất lượng phản hồi
    CASE 
        WHEN r.review_comment_title IS NOT NULL AND TRIM(r.review_comment_title) <> '' 
        THEN 1 
        ELSE 0 
    END AS has_comment_title,
    r.has_comment_message,

    -- 5. Dấu vết thời gian nạp dữ liệu
    CURRENT_TIMESTAMP AS dbt_created_at

FROM reviews r
LEFT JOIN orders_customer oc 
    ON r.order_id = oc.order_id
