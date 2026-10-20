{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'order_items', 'orders']
    )
}}

WITH source_data AS (
    -- Lấy bản ghi mới nhất theo mốc nạp dữ liệu (bảo toàn 112,650 dòng, xử lý lịch sử append-only của Bronze)
    SELECT * FROM {{ source('bronze', 'olist_order_items_dataset') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY order_id, order_item_id 
        ORDER BY _load_timestamp DESC
    ) = 1
),

cleaned_items AS (
    SELECT
        -- 0. Surrogate Key for Dimensional Performance
        {{ dbt_utils.generate_surrogate_key(['order_id', 'order_item_id']) }} AS order_item_key,

        -- 1. Natural Primary Key (Compound Atomic Grain)
        TRIM(CAST(order_id AS VARCHAR)) AS order_id,
        CAST(order_item_id AS INTEGER) AS order_item_id,

        -- 2. Foreign Keys to Dimensions
        TRIM(CAST(product_id AS VARCHAR)) AS product_id,
        TRIM(CAST(seller_id AS VARCHAR)) AS seller_id,

        -- 3. Temporal Attributes
        TRY_CAST(shipping_limit_date AS TIMESTAMP) AS shipping_limit_date,

        -- 4. Financial & Quantitative Measures (IFRS 15 Standard)
        TRY_CAST(price AS DECIMAL(10, 2)) AS price,
        TRY_CAST(freight_value AS DECIMAL(10, 2)) AS freight_value,
        (TRY_CAST(price AS DECIMAL(10, 2)) + TRY_CAST(freight_value AS DECIMAL(10, 2))) AS item_value,

        -- 5. Data Quality & Audit Flags (No Row Dropping, 100% Unique Grain Preserved)
        CASE 
            WHEN TRY_CAST(price AS DECIMAL(10, 2)) IS NULL THEN FALSE
            WHEN TRY_CAST(price AS DECIMAL(10, 2)) < 0 THEN FALSE
            ELSE TRUE 
        END AS is_valid_price,

        CASE 
            WHEN TRY_CAST(freight_value AS DECIMAL(10, 2)) IS NULL THEN FALSE
            WHEN TRY_CAST(freight_value AS DECIMAL(10, 2)) < 0 THEN FALSE
            ELSE TRUE 
        END AS is_valid_freight,

        CASE 
            WHEN TRY_CAST(freight_value AS DECIMAL(10, 2)) > 2 * TRY_CAST(price AS DECIMAL(10, 2)) 
                 AND TRY_CAST(price AS DECIMAL(10, 2)) > 0 
                THEN TRUE 
            ELSE FALSE 
        END AS is_high_freight_ratio,

        -- 6. Ingestion Lineage Metadata
        _load_timestamp,
        _source_file,
        _run_id

    FROM source_data
)

SELECT * FROM cleaned_items
