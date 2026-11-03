
{{ config(
    materialized = 'table'
) }}

-- =====================================================
-- MODEL: mart_customer_rfm
-- TASK 1: Prepare Customer RFM Features
-- Grain: 1 row / customer_unique_id
-- Source: mart_customer_360
-- =====================================================

WITH customer_rfm AS (

    SELECT
        -- Customer identifier
        CAST(customer_unique_id AS VARCHAR)
            AS customer_unique_id,

        -- Recency: Days since customer's last delivered order
        CAST(recency_days AS INTEGER)
            AS recency_days,

        -- Frequency: Total delivered orders
        CAST(total_orders AS INTEGER)
            AS frequency,

        -- Monetary: Total GMV from delivered orders
        CAST(total_gmv AS DECIMAL(10, 2))
            AS monetary

    FROM {{ ref('mart_customer_360') }}

)

SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,

    -- Reserved for K-Means clustering task
    CAST(NULL AS INTEGER) AS cluster_id,

    -- Reserved for customer segmentation task
    CAST(NULL AS VARCHAR) AS segment

FROM customer_rfm
