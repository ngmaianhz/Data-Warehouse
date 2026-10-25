{{
    config(
        tags=['gold', 'audit', 'financial']
    )
}}

-- ==============================================================================
-- GD3.28 - SINGULAR AUDIT TEST 4: ĐỐI SOÁT KHỚP DÒNG TIỀN TỪNG CENT
-- ==============================================================================
-- Tiêu chuẩn: ROUND(SUM(allocated_payment_value) - SUM(payment_value), 2) = 0.00
-- Đối soát giữa dòng tiền thực thu phân bổ trên fact_sales và tổng thanh toán
-- của các đơn hàng tương ứng từ silver_order_payments (bảo toàn thuật toán Hare-Niemeyer).
-- ==============================================================================

WITH fact_sales_alloc AS (
    SELECT 
        ROUND(SUM(allocated_payment_value), 2) AS total_allocated_payment
    FROM {{ ref('fact_sales') }}
),

matched_silver_payments AS (
    SELECT 
        ROUND(SUM(p.payment_value), 2) AS total_matched_payment
    FROM {{ ref('silver_order_payments') }} p
    WHERE p.order_id IN (SELECT DISTINCT order_id FROM {{ ref('fact_sales') }})
)

SELECT 
    f.total_allocated_payment,
    p.total_matched_payment,
    ROUND(f.total_allocated_payment - p.total_matched_payment, 2) AS penny_discrepancy
FROM fact_sales_alloc f
CROSS JOIN matched_silver_payments p
WHERE ROUND(f.total_allocated_payment - p.total_matched_payment, 2) != 0.00
