{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'category_translation']
    )
}}

WITH source_data AS (
    -- Deduplicate bản ghi mới nhất từ Bronze (bảo toàn chính xác 71 dòng, 100% số dòng so với Bronze)
    SELECT * FROM {{ source('bronze', 'product_category_name_translation') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY product_category_name 
        ORDER BY _load_timestamp DESC
    ) = 1
),

base_translation AS (
    SELECT
        -- 0. Surrogate Key
        {{ dbt_utils.generate_surrogate_key(['product_category_name']) }} AS category_key,

        -- 1. Descriptive Attributes (Natural PK)
        LOWER(TRIM(CAST(product_category_name AS VARCHAR))) AS product_category_name,
        LOWER(TRIM(CAST(product_category_name_english AS VARCHAR))) AS product_category_name_english,

        -- 2. Ingestion Lineage Metadata
        _load_timestamp,
        _source_file,
        _run_id
    FROM source_data
)

SELECT * FROM base_translation