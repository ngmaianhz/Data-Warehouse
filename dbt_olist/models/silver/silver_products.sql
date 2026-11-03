{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'products']
    )
}}

WITH source_data AS (
    -- Deduplicate bản ghi mới nhất từ Bronze
    SELECT * FROM {{ source('bronze', 'olist_products_dataset') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY product_id 
        ORDER BY _load_timestamp DESC
    ) = 1
),

category_translation AS (
    -- Đọc từ model Silver Category Translation đã qua làm sạch
    SELECT * FROM {{ ref('silver_category_translation') }}
),

joined_products AS (
    SELECT
        -- 0. Surrogate Key for Dimensional Performance
        {{ dbt_utils.generate_surrogate_key(['p.product_id']) }} AS product_key,

        -- 1. Natural Primary Key
        TRIM(CAST(p.product_id AS VARCHAR)) AS product_id,

        -- 2. Product Category Attributes & Translation (Gán 'unknown' cho danh mục khuyết theo đặc tả Báo cáo)
        COALESCE(LOWER(TRIM(CAST(p.product_category_name AS VARCHAR))), 'unknown') AS product_category_name,
        COALESCE(t.product_category_name_english, 'unknown') AS product_category_name_english,

        -- 3. Descriptive Measures (Sửa lỗi chính tả lenght -> length)
        TRY_CAST(p.product_name_lenght AS INTEGER) AS product_name_length,
        TRY_CAST(p.product_description_lenght AS INTEGER) AS product_description_length,
        TRY_CAST(p.product_photos_qty AS INTEGER) AS product_photos_qty,

        -- 4. Physical Dimensions & Measures
        TRY_CAST(p.product_weight_g AS DECIMAL(10, 2)) AS product_weight_g,
        TRY_CAST(p.product_length_cm AS DECIMAL(10, 2)) AS product_length_cm,
        TRY_CAST(p.product_height_cm AS DECIMAL(10, 2)) AS product_height_cm,
        TRY_CAST(p.product_width_cm AS DECIMAL(10, 2)) AS product_width_cm,

        -- 5. Audit Flags (Đánh dấu dòng thiếu thông tin gốc trước khi Impute)
        CASE 
            WHEN p.product_category_name IS NULL THEN TRUE 
            ELSE FALSE 
        END AS is_missing_category,

        CASE 
            WHEN p.product_weight_g IS NULL OR p.product_length_cm IS NULL THEN TRUE 
            ELSE FALSE 
        END AS is_missing_dimensions,

        -- 6. Ingestion Lineage Metadata
        p._load_timestamp,
        p._source_file,
        p._run_id

    FROM source_data p
    LEFT JOIN category_translation t
        ON LOWER(TRIM(CAST(p.product_category_name AS VARCHAR))) = t.product_category_name
),

imputed_products AS (
    -- Điền giá trị trung vị (MEDIAN) theo nhóm category cho các thông số bị thiếu
    SELECT
        product_key,
        product_id,
        product_category_name,
        product_category_name_english,

        COALESCE(
            product_name_length, 
            CAST(MEDIAN(product_name_length) OVER(PARTITION BY product_category_name) AS INTEGER)
        ) AS product_name_length,

        COALESCE(
            product_description_length, 
            CAST(MEDIAN(product_description_length) OVER(PARTITION BY product_category_name) AS INTEGER)
        ) AS product_description_length,

        COALESCE(
            product_photos_qty, 
            CAST(MEDIAN(product_photos_qty) OVER(PARTITION BY product_category_name) AS INTEGER)
        ) AS product_photos_qty,

        COALESCE(
            product_weight_g, 
            MEDIAN(product_weight_g) OVER(PARTITION BY product_category_name)
        ) AS product_weight_g,

        COALESCE(
            product_length_cm, 
            MEDIAN(product_length_cm) OVER(PARTITION BY product_category_name)
        ) AS product_length_cm,

        COALESCE(
            product_height_cm, 
            MEDIAN(product_height_cm) OVER(PARTITION BY product_category_name)
        ) AS product_height_cm,

        COALESCE(
            product_width_cm, 
            MEDIAN(product_width_cm) OVER(PARTITION BY product_category_name)
        ) AS product_width_cm,

        is_missing_category,
        is_missing_dimensions,

        _load_timestamp,
        _source_file,
        _run_id
    FROM joined_products
)

SELECT * FROM imputed_products