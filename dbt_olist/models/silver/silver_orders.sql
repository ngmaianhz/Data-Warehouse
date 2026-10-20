{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'orders']
    )
}}

WITH source_data AS (
    -- Lấy bản ghi mới nhất theo mốc nạp dữ liệu (bảo toàn 99,441 dòng, xử lý lịch sử append-only của Bronze)
    SELECT * FROM {{ source('bronze', 'olist_orders_dataset') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY order_id 
        ORDER BY _load_timestamp DESC
    ) = 1
),

cleaned_orders AS (
    SELECT
        -- 0. Surrogate Key for Dimensional Performance
        {{ dbt_utils.generate_surrogate_key(['order_id']) }} AS order_key,

        -- 1. Natural Primary Key & Foreign Keys
        TRIM(CAST(order_id AS VARCHAR)) AS order_id,
        TRIM(CAST(customer_id AS VARCHAR)) AS customer_id,

        -- 2. Conformed Dimension Attributes
        LOWER(TRIM(CAST(order_status AS VARCHAR))) AS order_status,

        -- 3. Temporal Attributes (TRY_CAST 5 timestamp columns)
        TRY_CAST(order_purchase_timestamp      AS TIMESTAMP) AS order_purchase_timestamp,
        TRY_CAST(order_approved_at             AS TIMESTAMP) AS order_approved_at,
        TRY_CAST(order_delivered_carrier_date  AS TIMESTAMP) AS order_delivered_carrier_date,
        TRY_CAST(order_delivered_customer_date AS TIMESTAMP) AS order_delivered_customer_date,
        TRY_CAST(order_estimated_delivery_date AS TIMESTAMP) AS order_estimated_delivery_date,

        -- 4. Data Quality & Audit Flags (No Row Dropping, 100% Bronze rows preserved)
        -- Cờ lỗi ép kiểu: có dữ liệu thô nhưng TRY_CAST ra NULL (thực tế: 0 dòng lỗi)
        CASE 
            WHEN (order_purchase_timestamp IS NOT NULL AND TRY_CAST(order_purchase_timestamp AS TIMESTAMP) IS NULL)
              OR (order_approved_at IS NOT NULL AND TRY_CAST(order_approved_at AS TIMESTAMP) IS NULL)
              OR (order_delivered_carrier_date IS NOT NULL AND TRY_CAST(order_delivered_carrier_date AS TIMESTAMP) IS NULL)
              OR (order_delivered_customer_date IS NOT NULL AND TRY_CAST(order_delivered_customer_date AS TIMESTAMP) IS NULL)
              OR (order_estimated_delivery_date IS NOT NULL AND TRY_CAST(order_estimated_delivery_date AS TIMESTAMP) IS NULL)
            THEN TRUE 
            ELSE FALSE 
        END AS has_cast_error,

        -- Cờ is_delivery_missing: Đơn đã 'delivered' mà thiếu ngày giao hàng (9 dòng).
        -- Hợp lệ (FALSE) khi status <> 'delivered' (chưa giao xong nên NULL là bình thường).
        CASE 
            WHEN LOWER(TRIM(CAST(order_status AS VARCHAR))) = 'delivered' 
                 AND (TRY_CAST(order_delivered_customer_date AS TIMESTAMP) IS NULL 
                      OR TRY_CAST(order_delivered_carrier_date AS TIMESTAMP) IS NULL)
            THEN TRUE 
            ELSE FALSE 
        END AS is_delivery_missing,

        -- Cờ is_valid_chronology: FALSE cho đúng 1,382 đơn hàng vi phạm thứ tự thời gian.
        -- Chi tiết: 1,359 đơn approved > carrier_date + 23 đơn carrier_date > customer_date.
        CASE 
            WHEN TRY_CAST(order_approved_at AS TIMESTAMP) > TRY_CAST(order_delivered_carrier_date AS TIMESTAMP)
              OR TRY_CAST(order_delivered_carrier_date AS TIMESTAMP) > TRY_CAST(order_delivered_customer_date AS TIMESTAMP)
              OR TRY_CAST(order_purchase_timestamp AS TIMESTAMP) > TRY_CAST(order_approved_at AS TIMESTAMP)
            THEN FALSE 
            ELSE TRUE 
        END AS is_valid_chronology,

        -- 5. Ingestion Lineage Metadata
        _load_timestamp,
        _source_file,
        _run_id

    FROM source_data
)

SELECT * FROM cleaned_orders
