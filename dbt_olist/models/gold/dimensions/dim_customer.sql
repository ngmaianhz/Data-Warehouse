WITH customer_orders AS (
    -- Lấy thông tin đơn hàng và đánh số thứ tự đơn hàng mới nhất của từng khách hàng
    SELECT 
        c.customer_id,
        c.customer_unique_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp DESC
        ) AS rn
    FROM {{ ref('silver_customers') }} c
    LEFT JOIN {{ ref('silver_orders') }} o 
        ON c.customer_id = o.customer_id
),

latest_customer_info AS (
    -- Lấy địa chỉ của đơn hàng mới nhất (rn = 1) theo SCD Type 1
    SELECT 
        customer_unique_id,
        customer_zip_code_prefix AS latest_zip_code_prefix,
        customer_city AS latest_city,
        customer_state AS latest_state
    FROM customer_orders
    WHERE rn = 1
),

customer_metrics AS (
    -- Tính ngày đặt hàng đầu tiên (first_order_date)
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM {{ ref('silver_customers') }} c
    LEFT JOIN {{ ref('silver_orders') }} o 
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),

geo_aggregated AS (
    -- Tính tọa độ địa lý đại diện (trung bình lat/lng) theo zip code
    SELECT 
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS latitude,
        AVG(geolocation_lng) AS longitude
    FROM {{ ref('silver_geolocation') }}
    GROUP BY geolocation_zip_code_prefix
)

SELECT 
    l.customer_unique_id,
    l.latest_zip_code_prefix,
    l.latest_city,
    l.latest_state,
    g.latitude,
    g.longitude,
    m.first_order_date
FROM latest_customer_info l
LEFT JOIN customer_metrics m 
    ON l.customer_unique_id = m.customer_unique_id
LEFT JOIN geo_aggregated g 
    ON l.latest_zip_code_prefix = g.geolocation_zip_code_prefix