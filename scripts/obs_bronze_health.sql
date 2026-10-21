-- ==============================================================================
-- GD3.7 - VIEW OBS_BRONZE_HEALTH: Observability Baseline cho Bronze Layer
-- ==============================================================================
-- View tổng hợp 3 chỉ số giám sát chất lượng vận hành (Data Observability):
--   (1) FRESHNESS   : Tính thời gian trôi qua kể từ lần nạp cuối (_load_timestamp)
--                     OK (<= 24h), WARN (> 24h), FAIL (> 168h / 7 ngày)
--   (2) VOLUME      : So sánh row_count_bronze giữa run hiện tại và run liền trước
--                     OK (bằng hoặc tăng), FAIL (giảm bất thường), WARN (chưa có run trước)
--   (3) SCHEMA DRIFT: So sánh schema_snapshot (danh sách cột + kiểu) giữa 2 lần nạp
--                     OK (trùng khớp hoàn toàn), FAIL (bị lệch cấu trúc)
-- ==============================================================================
-- LƯU Ý BÁO CÁO:
--   Olist là tập dữ liệu lịch sử TĨNH (Brazilian E-Commerce 2016-2018).
--   _load_timestamp phản ánh THỜI ĐIỂM THỰC THI PIPELINE nạp dữ liệu,
--   KHÔNG phản ánh độ tươi nghiệp vụ thực tế của đơn hàng Olist.
-- ==============================================================================

WITH ranked_runs AS (
    SELECT
        table_name,
        run_id,
        row_count_csv,
        row_count_bronze,
        schema_snapshot,
        load_timestamp,
        status,
        ROW_NUMBER() OVER (
            PARTITION BY table_name 
            ORDER BY load_timestamp DESC
        ) AS rn
    FROM bronze_ingestion_log
    WHERE status = 'SUCCESS'
),

current_run AS (
    SELECT * FROM ranked_runs WHERE rn = 1
),

previous_run AS (
    SELECT * FROM ranked_runs WHERE rn = 2
),

freshness_calc AS (
    SELECT
        c.table_name,
        c.run_id AS latest_run_id,
        c.load_timestamp AS latest_load_timestamp,
        ROUND(DATEDIFF('minute', c.load_timestamp, CURRENT_TIMESTAMP) / 60.0, 2) AS hours_since_load,
        CASE
            WHEN DATEDIFF('hour', c.load_timestamp, CURRENT_TIMESTAMP) > 168 THEN 'FAIL'
            WHEN DATEDIFF('hour', c.load_timestamp, CURRENT_TIMESTAMP) > 24  THEN 'WARN'
            ELSE 'OK'
        END AS freshness_status,
        CASE
            WHEN DATEDIFF('hour', c.load_timestamp, CURRENT_TIMESTAMP) > 168 
                THEN 'Chưa nạp > 7 ngày (error_after: 168h)'
            WHEN DATEDIFF('hour', c.load_timestamp, CURRENT_TIMESTAMP) > 24  
                THEN 'Chưa nạp > 24h (warn_after: 24h) - Bình thường với data tĩnh Olist'
            ELSE 'Nạp trong vòng 24h gần nhất (Đạt chuẩn)'
        END AS freshness_note
    FROM current_run c
),

volume_calc AS (
    SELECT
        c.table_name,
        c.row_count_bronze AS current_rows,
        p.row_count_bronze AS prev_rows,
        CASE
            WHEN p.row_count_bronze IS NULL THEN 'WARN'
            WHEN c.row_count_bronze < p.row_count_bronze THEN 'FAIL'
            ELSE 'OK'
        END AS volume_status,
        CASE
            WHEN p.row_count_bronze IS NULL THEN 'Lần nạp đầu tiên, chưa có dữ liệu đối chiếu'
            WHEN c.row_count_bronze < p.row_count_bronze 
                THEN 'CẢNH BÁO: Số dòng giảm (' || CAST(c.row_count_bronze AS VARCHAR) || ' < ' || CAST(p.row_count_bronze AS VARCHAR) || ')'
            ELSE 'Số dòng ổn định: ' || CAST(c.row_count_bronze AS VARCHAR) || ' (Trước: ' || CAST(COALESCE(p.row_count_bronze, 0) AS VARCHAR) || ')'
        END AS volume_note
    FROM current_run c
    LEFT JOIN previous_run p USING (table_name)
),

schema_calc AS (
    SELECT
        c.table_name,
        c.schema_snapshot AS current_schema,
        p.schema_snapshot AS prev_schema,
        CASE
            WHEN p.schema_snapshot IS NULL THEN 'WARN'
            WHEN c.schema_snapshot <> p.schema_snapshot THEN 'FAIL'
            ELSE 'OK'
        END AS schema_status,
        CASE
            WHEN p.schema_snapshot IS NULL THEN 'Lần nạp đầu tiên, lưu snapshot cấu trúc'
            WHEN c.schema_snapshot <> p.schema_snapshot THEN 'SCHEMA DRIFT: Cấu trúc cột/kiểu dữ liệu đã bị thay đổi!'
            ELSE 'Schema ổn định, 100% khớp snapshot lần nạp trước'
        END AS schema_note
    FROM current_run c
    LEFT JOIN previous_run p USING (table_name)
)

SELECT
    f.table_name,
    f.latest_run_id,
    f.latest_load_timestamp,
    f.hours_since_load,
    f.freshness_status,
    f.freshness_note,
    v.current_rows,
    v.prev_rows,
    v.volume_status,
    v.volume_note,
    s.schema_status,
    s.schema_note,
    CASE
        WHEN 'FAIL' IN (f.freshness_status, v.volume_status, s.schema_status) THEN 'FAIL'
        WHEN 'WARN' IN (f.freshness_status, v.volume_status, s.schema_status) THEN 'WARN'
        ELSE 'OK'
    END AS overall_health,
    CURRENT_TIMESTAMP AS checked_at
FROM freshness_calc f
JOIN volume_calc v USING (table_name)
JOIN schema_calc s USING (table_name)
ORDER BY
    CASE 
        WHEN 'FAIL' IN (f.freshness_status, v.volume_status, s.schema_status) THEN 1
        WHEN 'WARN' IN (f.freshness_status, v.volume_status, s.schema_status) THEN 2
        ELSE 3
    END,
    f.table_name;
