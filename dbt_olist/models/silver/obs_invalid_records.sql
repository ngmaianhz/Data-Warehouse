{{
    config(
        materialized='view',
        schema='silver',
        tags=['silver', 'observability', 'audit']
    )
}}

-- ==============================================================================
-- GD3.18 - OBSERVABILITY GATE: VIEW TỔNG HỢP CÁC DÒNG BỊ GẮN CỜ LỖI (Team 7)
-- ==============================================================================
-- Mục đích:
--   1. Tổng hợp toàn bộ các dòng dữ liệu bị gắn cờ cảnh báo / lỗi chất lượng (DQ flags)
--      phát hiện tại tầng Silver phục vụ kiểm toán dữ liệu mà không làm rơi dòng thô:
--      - is_delivery_missing = TRUE: Đơn hàng 'delivered' thiếu ngày giao thực tế (9 dòng).
--      - is_valid_chronology = FALSE: Đơn hàng sai lệch trình tự mốc thời gian (1,382 dòng).
--      - is_valid_payment = FALSE: Dòng thanh toán có phương thức 'unknown' hoặc số tiền lỗi (3 dòng).
--   2. Chuẩn hóa grain kiểm toán: Mỗi vi phạm là 1 dòng với audit_id băm duy nhất.
-- ==============================================================================

WITH delivery_missing_orders AS (
    SELECT
        'orders' AS entity_name,
        'silver_orders' AS source_model,
        TRIM(CAST(order_id AS VARCHAR)) AS record_id,
        order_key AS surrogate_key,
        'is_delivery_missing' AS flag_name,
        'TRUE' AS flag_value,
        'MEDIUM' AS error_severity,
        'MISSING_DELIVERY_TIMESTAMP' AS error_category,
        'Đơn hàng trạng thái delivered nhưng thiếu ngày giao khách hàng thực tế (order_delivered_customer_date IS NULL)' AS audit_issue_desc,
        _load_timestamp,
        _run_id
    FROM {{ ref('silver_orders') }}
    WHERE is_delivery_missing = TRUE
),

chronology_violation_orders AS (
    SELECT
        'orders' AS entity_name,
        'silver_orders' AS source_model,
        TRIM(CAST(order_id AS VARCHAR)) AS record_id,
        order_key AS surrogate_key,
        'is_valid_chronology' AS flag_name,
        'FALSE' AS flag_value,
        'LOW' AS error_severity,
        'CHRONOLOGY_SEQUENCE_VIOLATION' AS error_category,
        'Sai lệch thứ tự thời gian tiến trình đơn hàng (order_approved_at > carrier_date hoặc carrier_date > customer_date)' AS audit_issue_desc,
        _load_timestamp,
        _run_id
    FROM {{ ref('silver_orders') }}
    WHERE is_valid_chronology = FALSE
),

invalid_payments AS (
    SELECT
        'order_payments' AS entity_name,
        'silver_order_payments' AS source_model,
        TRIM(CAST(order_id AS VARCHAR)) || '-' || CAST(payment_sequential AS VARCHAR) AS record_id,
        payment_key AS surrogate_key,
        'is_valid_payment' AS flag_name,
        'FALSE' AS flag_value,
        'HIGH' AS error_severity,
        'INVALID_PAYMENT_METRIC' AS error_category,
        CASE
            WHEN payment_type = 'unknown' THEN 'Phương thức thanh toán bất thường (not_defined được chuẩn hóa về unknown)'
            WHEN is_negative_payment = TRUE THEN 'Giá trị thanh toán âm (payment_value < 0)'
            ELSE 'Giá trị thanh toán không hợp lệ'
        END AS audit_issue_desc,
        _load_timestamp,
        _run_id
    FROM {{ ref('silver_order_payments') }}
    WHERE is_valid_payment_value = FALSE 
       OR payment_type = 'unknown' 
       OR is_negative_payment = TRUE
),

unified_invalid_records AS (
    SELECT * FROM delivery_missing_orders
    UNION ALL
    SELECT * FROM chronology_violation_orders
    UNION ALL
    SELECT * FROM invalid_payments
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['entity_name', 'record_id', 'flag_name']) }} AS audit_id,
    entity_name,
    source_model,
    record_id,
    surrogate_key,
    flag_name,
    flag_value,
    error_severity,
    error_category,
    audit_issue_desc,
    _load_timestamp,
    _run_id
FROM unified_invalid_records
