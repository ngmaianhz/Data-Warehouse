-- dbt_olist/models/silver/silver_sellers.sql

WITH source AS (
    SELECT * 
    FROM {{ source('bronze', 'raw_sellers') }}
)

SELECT
    CAST(seller_id AS VARCHAR) AS seller_id,
    
    -- Ép kiểu VARCHAR và dùng LPAD thêm số 0 đằng trước cho đủ 5 chữ số
    LPAD(CAST(seller_zip_code_prefix AS VARCHAR), 5, '0') AS seller_zip_code_prefix,
    
    -- Chuẩn hóa city: trim, chuyển chữ thường (lowercase) và bỏ dấu
    LOWER(TRIM(strip_accents(seller_city))) AS seller_city,
    
    -- Chuẩn hóa state: trim và viết hoa (uppercase)
    UPPER(TRIM(seller_state)) AS seller_state

FROM source
WHERE seller_id IS NOT NULL