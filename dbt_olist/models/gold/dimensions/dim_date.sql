{{
    config(
        materialized='table',
        schema='gold',
        tags=['gold', 'dimensions', 'date']
    )
}}

-- ==============================================================================
-- BẢNG CHIỀU THỜI GIAN (dim_date)
-- ==============================================================================
-- Chuẩn hóa trục thời gian phân tích từ 2016-01-01 đến 2018-12-31
-- Khóa chính: date_key (INTEGER YYYYMMDD)
-- Tích hợp bản ghi Sentinel (-1) đại diện cho đơn chưa giao (not delivered / unknown)
-- ==============================================================================

WITH date_spine AS (
    SELECT 
        CAST(range AS DATE) AS date_day
    FROM range(DATE '2016-01-01', DATE '2019-01-01', INTERVAL 1 DAY)
),

calculated_dates AS (
    SELECT
        CAST(strftime(date_day, '%Y%m%d') AS INTEGER) AS date_key,
        date_day,
        EXTRACT(year FROM date_day)::INTEGER AS year,
        EXTRACT(quarter FROM date_day)::INTEGER AS quarter,
        EXTRACT(month FROM date_day)::INTEGER AS month,
        EXTRACT(day FROM date_day)::INTEGER AS day,
        EXTRACT(dayofweek FROM date_day)::INTEGER AS day_of_week,
        strftime(date_day, '%A') AS day_name,
        strftime(date_day, '%B') AS month_name,
        CASE WHEN EXTRACT(dayofweek FROM date_day) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend
    FROM date_spine
),

sentinel_record AS (
    SELECT
        -1 AS date_key,
        NULL::DATE AS date_day,
        -1 AS year,
        -1 AS quarter,
        -1 AS month,
        -1 AS day,
        -1 AS day_of_week,
        'Unknown' AS day_name,
        'Unknown' AS month_name,
        FALSE AS is_weekend
)

SELECT * FROM calculated_dates
UNION ALL
SELECT * FROM sentinel_record
ORDER BY date_key ASC
