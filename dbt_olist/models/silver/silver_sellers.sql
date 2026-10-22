{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'sellers']
    )
}}

WITH source_data AS (
    -- Lấy bản ghi mới nhất theo mốc nạp dữ liệu (bảo toàn 3,095 dòng, xử lý lịch sử append-only của Bronze)
    SELECT * FROM {{ source('bronze', 'raw_sellers') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY seller_id 
        ORDER BY _load_timestamp DESC
    ) = 1
),

cleaned_sellers AS (
    SELECT
        -- 0. Surrogate Key for Dimensional Performance
        {{ dbt_utils.generate_surrogate_key(['seller_id']) }} AS seller_key,

        -- 1. Natural Primary Key
        TRIM(CAST(seller_id AS VARCHAR)) AS seller_id,

        -- 2. Geographic Attributes (LPAD 5 digits & Clean text)
        LPAD(TRIM(CAST(seller_zip_code_prefix AS VARCHAR)), 5, '0') AS seller_zip_code_prefix,
        LOWER(TRIM(strip_accents(CAST(seller_city AS VARCHAR)))) AS seller_city,
        UPPER(TRIM(CAST(seller_state AS VARCHAR))) AS seller_state,

        -- 3. Ingestion Lineage Metadata
        _load_timestamp,
        _source_file,
        _run_id

    FROM source_data
    WHERE seller_id IS NOT NULL
)

SELECT * FROM cleaned_sellers