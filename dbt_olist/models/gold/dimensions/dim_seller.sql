WITH sellers AS (
    SELECT 
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state
    FROM {{ ref('silver_sellers') }}
),

geo_aggregated AS (
    -- Tính tọa độ địa lý đại diện (trung bình lat/lng) theo zip code (đồng bộ kiến trúc với dim_customer)
    SELECT 
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS latitude,
        AVG(geolocation_lng) AS longitude
    FROM {{ ref('silver_geolocation') }}
    GROUP BY geolocation_zip_code_prefix
)

SELECT 
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,
    g.latitude,
    g.longitude
FROM sellers s
LEFT JOIN geo_aggregated g 
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
