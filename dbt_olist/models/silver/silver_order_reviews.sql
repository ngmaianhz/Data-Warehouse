{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'order_reviews', 'reviews']
    )
}}

WITH source_data AS (
    -- Lấy bản ghi mới nhất theo mốc nạp dữ liệu (xử lý lịch sử append-only của Bronze)
    -- Khóa chính ghép (review_id, order_id) bảo toàn 100% số dòng Bronze do không bị trùng lặp
    SELECT * FROM {{ source('bronze', 'olist_order_reviews_dataset') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY review_id, order_id 
        ORDER BY _load_timestamp DESC
    ) = 1
),

cleaned_reviews AS (
    SELECT
        -- 0. Surrogate Key for Dimensional Performance
        {{ dbt_utils.generate_surrogate_key(['review_id', 'order_id']) }} AS review_key,

        -- 1. Natural Primary Key (Compound Key) & Foreign Key
        TRIM(CAST(review_id AS VARCHAR)) AS review_id,
        TRIM(CAST(order_id AS VARCHAR)) AS order_id,

        -- 2. Review Metrics & Scores (Ép kiểu sang INT)
        CAST(review_score AS INTEGER) AS review_score,

        -- 3. Review Comments & Flags
        -- Điền '' cho comment title bị NULL
        COALESCE(TRIM(CAST(review_comment_title AS VARCHAR)), '') AS review_comment_title,
        TRIM(CAST(review_comment_message AS VARCHAR)) AS review_comment_message,

        -- Cột cờ boolean has_comment_message theo yêu cầu Task 3.11b
        CASE 
            WHEN review_comment_message IS NOT NULL AND TRIM(review_comment_message) <> '' 
            THEN 1 
            ELSE 0 
        END AS has_comment_message,

        -- 4. Temporal Attributes
        TRY_CAST(review_creation_date AS TIMESTAMP) AS review_creation_date,
        TRY_CAST(review_answer_timestamp AS TIMESTAMP) AS review_answer_timestamp,

        -- 5. Ingestion Lineage Metadata
        _load_timestamp,
        _source_file,
        _run_id

    FROM source_data
)

SELECT * FROM cleaned_reviews
