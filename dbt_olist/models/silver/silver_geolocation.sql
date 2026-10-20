{{
    config(
        materialized='table',
        schema='silver',
        tags=['silver', 'geolocation', 'spatial']
    )
}}

WITH raw_deduplicated AS (
    -- Bước 1: Khử trùng lặp giữa các đợt nạp append-only để giảm tải khối lượng tính toán chuỗi trên MotherDuck
    SELECT DISTINCT
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    FROM {{ source('bronze', 'olist_geolocation_dataset') }}
),

base_geo AS (
    SELECT
        -- Bước 2: Bù số 0 đầu mã bưu chính đảm bảo chuẩn 5 ký tự
        LPAD(TRIM(CAST(geolocation_zip_code_prefix AS VARCHAR)), 5, '0') AS zip_code_prefix,
        TRY_CAST(geolocation_lat AS DOUBLE) AS lat_raw,
        TRY_CAST(geolocation_lng AS DOUBLE) AS lng_raw,
        -- Chuẩn hóa chữ thường, cắt khoảng trắng và loại bỏ dấu tiếng Bồ Đào Nha
        strip_accents(LOWER(TRIM(CAST(geolocation_city AS VARCHAR)))) AS city_clean,
        UPPER(TRIM(CAST(geolocation_state AS VARCHAR))) AS state_clean
    FROM raw_deduplicated
),

bounded_coordinates AS (
    SELECT
        zip_code_prefix,
        lat_raw,
        lng_raw,
        city_clean,
        state_clean,
        -- Bounding box Brazil: Lat [-34.0, +6.0] (bao trọn Chuí ở cực Nam -33.75° đến Monte Caburaí ở cực Bắc +5.27°)
        -- Lng [-74.0, -32.0] (bao trọn Serra do Divisor ở cực Tây -73.98° đến quần đảo Fernando de Noronha ở cực Đông -32.41°)
        CASE
            WHEN lat_raw BETWEEN -34.0 AND 6.0 AND lng_raw BETWEEN -74.0 AND -32.0 THEN TRUE
            ELSE FALSE
        END AS is_inside_brazil_bbox
    FROM base_geo
),

aggregated_geolocation AS (
    SELECT
        zip_code_prefix,
        
        -- Tọa độ trung tâm đại diện cho mã zip (làm tròn 6 chữ số thập phân ~ 10cm)
        ROUND(AVG(CASE WHEN is_inside_brazil_bbox THEN lat_raw END), 6) AS geolocation_lat,
        ROUND(AVG(CASE WHEN is_inside_brazil_bbox THEN lng_raw END), 6) AS geolocation_lng,

        -- Chọn tên thành phố và bang xuất hiện phổ biến nhất (MODE)
        MODE(city_clean) AS geolocation_city,
        MODE(state_clean) AS geolocation_state,

        -- Thống kê số lượng điểm GPS gốc đã gom nhóm
        COUNT(*) AS coordinate_sample_size,
        COUNT(CASE WHEN is_inside_brazil_bbox THEN 1 END) AS valid_coordinate_points,

        -- Cờ kiểm toán: TRUE nếu có tọa độ trung tâm hợp lệ trong lãnh thổ Brazil
        CASE
            WHEN COUNT(CASE WHEN is_inside_brazil_bbox THEN 1 END) > 0 THEN TRUE
            ELSE FALSE
        END AS is_valid_coordinates

    FROM bounded_coordinates
    GROUP BY zip_code_prefix
)

SELECT
    -- 0. Surrogate Key cho Dimension địa lý
    {{ dbt_utils.generate_surrogate_key(['zip_code_prefix']) }} AS geolocation_key,
    
    -- 1. Khóa chính tự nhiên
    zip_code_prefix AS geolocation_zip_code_prefix,
    
    -- 2. Tọa độ trung tâm đại diện
    geolocation_lat,
    geolocation_lng,
    
    -- 3. Đơn vị hành chính chuẩn hóa
    geolocation_city,
    geolocation_state,
    
    -- 4. Thuộc tính kiểm toán chất lượng dữ liệu
    is_valid_coordinates,
    coordinate_sample_size,
    valid_coordinate_points,
    CURRENT_TIMESTAMP AS dbt_updated_at

FROM aggregated_geolocation
