{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'order_payments', 'finance']
    )
}}

WITH source_data AS (
    -- Lấy bản ghi mới nhất theo mốc nạp dữ liệu (bảo toàn 103,886 dòng, xử lý lịch sử append-only của Bronze)
    SELECT * FROM {{ source('bronze', 'olist_order_payments_dataset') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY order_id, payment_sequential 
        ORDER BY _load_timestamp DESC
    ) = 1
),

cleaned_payments AS (
    SELECT
        -- 0. Surrogate Key for Dimensional Performance
        {{ dbt_utils.generate_surrogate_key(['order_id', 'payment_sequential']) }} AS payment_key,

        -- 1. Natural Primary Key (Compound Atomic Grain)
        TRIM(CAST(order_id AS VARCHAR)) AS order_id,
        CAST(payment_sequential AS INTEGER) AS payment_sequential,

        -- 2. Categorical Dimension & Conforming Logic
        -- Chuẩn hóa giá trị bất thường: 3 dòng 'not_defined' -> 'unknown' theo EDA
        CASE 
            WHEN LOWER(TRIM(CAST(payment_type AS VARCHAR))) = 'not_defined' THEN 'unknown'
            WHEN payment_type IS NULL OR TRIM(CAST(payment_type AS VARCHAR)) = '' THEN 'unknown'
            ELSE LOWER(TRIM(CAST(payment_type AS VARCHAR)))
        END AS payment_type,

        -- 3. Payment Installments
        COALESCE(CAST(payment_installments AS INTEGER), 1) AS payment_installments,

        -- 4. Financial Measure
        TRY_CAST(payment_value AS DECIMAL(10, 2)) AS payment_value,

        -- 5. Data Quality & Audit Flags (Calibrated via Nature Reviewer)
        -- Phân biệt rành mạch giữa 0đ hợp lệ (voucher 100%) vs giá trị âm/lỗi
        CASE 
            WHEN TRY_CAST(payment_value AS DECIMAL(10, 2)) = 0.00 THEN TRUE 
            ELSE FALSE 
        END AS is_zero_payment,

        CASE 
            WHEN TRY_CAST(payment_value AS DECIMAL(10, 2)) < 0.00 THEN TRUE 
            ELSE FALSE 
        END AS is_negative_payment,

        CASE 
            WHEN TRY_CAST(payment_value AS DECIMAL(10, 2)) >= 0.00 THEN TRUE 
            ELSE FALSE 
        END AS is_valid_payment_value,

        CASE 
            WHEN LOWER(TRIM(CAST(payment_type AS VARCHAR))) = 'voucher' THEN TRUE 
            ELSE FALSE 
        END AS is_voucher_payment,

        -- 6. Ingestion Lineage Metadata
        _load_timestamp,
        _source_file,
        _run_id

    FROM source_data
)

SELECT * FROM cleaned_payments
