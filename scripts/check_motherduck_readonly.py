"""Kiểm tra MotherDuck chỉ với SELECT; không CREATE/UPDATE dữ liệu."""
import os
import sys
from pathlib import Path
from dotenv import load_dotenv
import duckdb

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ROOT = Path(__file__).resolve().parent.parent
ENV = ROOT / '.env'
print('Project root:', ROOT)
print('.env exists:', ENV.is_file())
if not ENV.is_file():
    sys.exit('ERROR: Không tìm thấy .env trong thư mục gốc repository.')
load_dotenv(ENV, override=True)
token = os.getenv('MOTHERDUCK_TOKEN', '').strip()
db = os.getenv('MOTHERDUCK_DATABASE', 'olist_warehouse').strip()
if not token:
    sys.exit('ERROR: MOTHERDUCK_TOKEN trống.')
if db != 'olist_warehouse':
    print('WARNING: MOTHERDUCK_DATABASE không phải olist_warehouse; hãy kiểm tra cấu hình.')
print('Token loaded: YES (không hiển thị nội dung)')
print('Database:', db)

try:
    # Tránh gắn token vào connection string hoặc ghi token trong thông báo lỗi.
    os.environ['motherduck_token'] = token
    con = duckdb.connect(f'md:{db}')
    print('SELECT 1:', con.execute('SELECT 1').fetchone()[0])
    tables = con.execute('''
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema IN ('main_gold','main_mart','gold','mart')
          AND table_name IN ('fact_sales','dim_customer','mart_customer_360','mart_customer_rfm','dim_customer_cluster')
        ORDER BY table_schema, table_name
    ''').fetchall()
    print('Các bảng tìm thấy:')
    for schema, table in tables:
        print(f' - {schema}.{table}')
    print(f'SUCCESS: Có thể đọc MotherDuck; tìm thấy {len(tables)} bảng cần kiểm tra.')
    con.close()
except Exception as e:
    # Phòng trường hợp thông báo lỗi chứa chuỗi kết nối hoặc token.
    safe = str(e).replace(token, '[TOKEN_HIDDEN]')
    print('FAILED:', type(e).__name__, safe)
    sys.exit(1)
