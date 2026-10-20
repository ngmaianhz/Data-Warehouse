{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'category_translation']
    )
}}

WITH source_data AS (
    -- Deduplicate bản ghi mới nhất từ Bronze
    SELECT * FROM {{ source('bronze', 'product_category_name_translation') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY product_category_name 
        ORDER BY _load_timestamp DESC
    ) = 1
),

base_translation AS (
    SELECT
        -- Natural Primary Key
        LOWER(TRIM(CAST(product_category_name AS VARCHAR))) AS product_category_name,
        LOWER(TRIM(CAST(product_category_name_english AS VARCHAR))) AS product_category_name_english,

        -- Lineage Metadata
        _load_timestamp,
        _source_file,
        _run_id
    FROM source_data
),

-- Bổ sung thủ công 2 danh mục còn thiếu trong từ điển Olist
manual_additions AS (
    SELECT 
        'pc_gamer' AS product_category_name, 
        'pc_gamer' AS product_category_name_english,
        CURRENT_TIMESTAMP AS _load_timestamp,
        'manual_override' AS _source_file,
        'manual_fix' AS _run_id
    UNION ALL
    SELECT 
        'portateis_cozinha_e_preparadores_de_alimentos' AS product_category_name, 
        'small_appliances_kitchen_food_preparers' AS product_category_name_english,
        CURRENT_TIMESTAMP AS _load_timestamp,
        'manual_override' AS _source_file,
        'manual_fix' AS _run_id
),

combined_translation AS (
    SELECT * FROM base_translation
    UNION ALL
    SELECT * FROM manual_additions
    WHERE product_category_name NOT IN (SELECT product_category_name FROM base_translation)
),

final_translation AS (
    SELECT
        -- 0. Surrogate Key
        {{ dbt_utils.generate_surrogate_key(['product_category_name']) }} AS category_key,

        -- 1. Descriptive Attributes
        product_category_name,
        product_category_name_english,

        -- 2. Audit & Data Quality Flags
        CASE 
            WHEN _source_file = 'manual_override' THEN TRUE 
            ELSE FALSE 
        END AS is_manual_override,

        -- 3. Ingestion Lineage Metadata
        _load_timestamp,
        _source_file,
        _run_id
    FROM combined_translation
)

SELECT * FROM final_translation