{{
    config(
        materialized='table',
        schema='gold',
        tags=['gold', 'dimensions', 'payment_type']
    )
}}

-- ==============================================================================
-- GD3.25 - XÂY DỰNG BẢNG CHIỀU PHƯƠNG THỨC THANH TOÁN (dim_payment_type)
-- ==============================================================================
-- Đặc điểm: Bảng chiều kích thước nhỏ (Static Dimension)
-- Chuẩn hóa 5 kênh thanh toán nghiệp vụ + 1 bản ghi giả lập -1 (Sentinel Record)
-- Khóa chính: payment_type_key (INTEGER)
-- Ranh giới kiến trúc: Gắn trực tiếp vào fact_sales qua primary_payment_type_key
-- (được tính bằng ARG_MAX(payment_type, payment_value)) để cắt lát doanh số
-- ==============================================================================

WITH payment_type_base AS (
    -- 5 kênh thanh toán nghiệp vụ chuẩn hóa
    SELECT 
        1 AS payment_type_key,
        'credit_card' AS payment_type,
        'Credit Card' AS payment_type_name,
        'Thẻ tín dụng' AS payment_type_name_vi,
        'Card' AS payment_category,
        TRUE AS is_installment_eligible
    UNION ALL
    SELECT 
        2 AS payment_type_key,
        'boleto' AS payment_type,
        'Boleto Bancário' AS payment_type_name,
        'Boleto (Hóa đơn ngân hàng)' AS payment_type_name_vi,
        'Cash / Bank Voucher' AS payment_category,
        FALSE AS is_installment_eligible
    UNION ALL
    SELECT 
        3 AS payment_type_key,
        'voucher' AS payment_type,
        'Voucher' AS payment_type_name,
        'Phiếu giảm giá (Voucher)' AS payment_type_name_vi,
        'Voucher' AS payment_category,
        FALSE AS is_installment_eligible
    UNION ALL
    SELECT 
        4 AS payment_type_key,
        'debit_card' AS payment_type,
        'Debit Card' AS payment_type_name,
        'Thẻ ghi nợ' AS payment_type_name_vi,
        'Card' AS payment_category,
        FALSE AS is_installment_eligible
    UNION ALL
    SELECT 
        5 AS payment_type_key,
        'unknown' AS payment_type,
        'Unknown / Not Defined' AS payment_type_name,
        'Không xác định' AS payment_type_name_vi,
        'Unknown' AS payment_category,
        FALSE AS is_installment_eligible
    
    UNION ALL

    -- 1 bản ghi giả lập đặc biệt (-1) phục vụ các trường hợp thiếu/chưa xác định
    SELECT 
        -1 AS payment_type_key,
        'missing' AS payment_type,
        'Missing / Not Applicable' AS payment_type_name,
        'Chưa có / Không áp dụng' AS payment_type_name_vi,
        'Missing' AS payment_category,
        FALSE AS is_installment_eligible
)

SELECT 
    payment_type_key,
    payment_type,
    payment_type_name,
    payment_type_name_vi,
    payment_category,
    is_installment_eligible
FROM payment_type_base
ORDER BY payment_type_key ASC
