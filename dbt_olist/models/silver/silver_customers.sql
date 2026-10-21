-- dbt_olist/models/silver/silver_customers.sql

WITH source AS (
    SELECT * 
    FROM {{ source('bronze', 'raw_customers') }}
)

SELECT
    CAST(customer_id AS VARCHAR) AS customer_id,
    CAST(customer_unique_id AS VARCHAR) AS customer_unique_id,
    
    -- Ép kiểu VARCHAR và dùng LPAD thêm số 0 đằng trước cho đủ 5 chữ số
    LPAD(CAST(customer_zip_code_prefix AS VARCHAR), 5, '0') AS customer_zip_code_prefix,
    
    -- Chuẩn hóa city: trim, chuyển chữ thường (lowercase) và bỏ dấu tiếng Bồ Đào Nha
    LOWER(TRIM(strip_accents(customer_city))) AS customer_city,
    
    -- Chuẩn hóa state: trim và viết hoa (uppercase)
    UPPER(TRIM(customer_state)) AS customer_state

FROM source
WHERE customer_id IS NOT NULL