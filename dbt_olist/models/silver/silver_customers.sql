{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'customers']
    )
}}

WITH source_data AS (
    -- Lấy bản ghi mới nhất theo mốc nạp dữ liệu (bảo toàn 99,441 dòng, xử lý lịch sử append-only của Bronze)
    SELECT * FROM {{ source('bronze', 'raw_customers') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY customer_id 
        ORDER BY _load_timestamp DESC
    ) = 1
),

cleaned_customers AS (
    SELECT
        -- 0. Surrogate Key for Dimensional Performance
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} AS customer_key,

        -- 1. Natural Primary Key & Customer Identifiers
        TRIM(CAST(customer_id AS VARCHAR)) AS customer_id,
        TRIM(CAST(customer_unique_id AS VARCHAR)) AS customer_unique_id,

        -- 2. Geographic Attributes (LPAD 5 digits & Clean text)
        LPAD(TRIM(CAST(customer_zip_code_prefix AS VARCHAR)), 5, '0') AS customer_zip_code_prefix,
        LOWER(TRIM(strip_accents(CAST(customer_city AS VARCHAR)))) AS customer_city,
        UPPER(TRIM(CAST(customer_state AS VARCHAR))) AS customer_state,

        -- 3. Ingestion Lineage Metadata
        _load_timestamp,
        _source_file,
        _run_id

    FROM source_data
    WHERE customer_id IS NOT NULL
)

SELECT * FROM cleaned_customers