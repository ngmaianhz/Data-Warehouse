"""
================================================================================
SCRIPT KIỂM TRA KẾT NỐI MOTHERDUCK (TASK GD3.1)
Dự án: Olist E-Commerce Data Warehouse - Nhóm 7 (PCCV)
================================================================================
Mục đích:
- Nạp cấu hình từ file .env (chứa MOTHERDUCK_TOKEN)
- Tạo database 'olist_warehouse' trên MotherDuck (nếu chưa có)
- Kết nối tới MotherDuck: duckdb.connect('md:olist_warehouse')
- Thực thi câu lệnh test: SELECT 1
- Trả về thông tin phiên bản DuckDB, Database hiện tại, và trạng thái kết nối
================================================================================
"""

import os
import sys
from pathlib import Path
from datetime import datetime

# Cấu hình UTF-8 cho console Windows
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# 1. Định vị thư mục gốc dự án và nạp .env
BASE_DIR = Path(__file__).resolve().parent.parent
ENV_PATH = BASE_DIR / ".env"

try:
    from dotenv import load_dotenv
    if ENV_PATH.exists():
        load_dotenv(dotenv_path=ENV_PATH)
    else:
        print(f"[!] CẢNH BÁO: Không tìm thấy file .env tại {ENV_PATH}")
except ImportError:
    print("[X] LỖI: Thư viện 'python-dotenv' chưa được cài đặt. Vui lòng chạy: pip install python-dotenv")
    sys.exit(1)

try:
    import duckdb
except ImportError:
    print("[X] LỖI: Thư viện 'duckdb' chưa được cài đặt. Vui lòng chạy: pip install duckdb")
    sys.exit(1)


def main():
    print("=" * 70)
    print("   KIỂM TRA KẾT NỐI MOTHERDUCK CLOUD - OLIST DATA WAREHOUSE (GD3.1)")
    print("=" * 70)
    print(f"Thời gian kiểm tra : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Đường dẫn repo     : {BASE_DIR}")
    print(f"File cấu hình .env : {ENV_PATH.name} (Tồn tại: {'Có' if ENV_PATH.exists() else 'Không'})")

    # 2. Kiểm tra token
    token = os.getenv("MOTHERDUCK_TOKEN")
    db_name = os.getenv("MOTHERDUCK_DATABASE", "olist_warehouse").strip()

    if not token or token.strip() == "" or token == "your_motherduck_token_here":
        print("\n" + "-" * 70)
        print("[!] CHƯA CÓ MOTHERDUCK_TOKEN TRONG FILE .env")
        print("-" * 70)
        print("Vui lòng thực hiện các bước sau:")
        print("1. Truy cập https://motherduck.com và đăng ký / đăng nhập tài khoản.")
        print("2. Vào Settings -> Access Tokens -> Bấm Create Token và sao chép mã.")
        print(f"3. Mở file .env tại: {ENV_PATH}")
        print("4. Điền mã token vào: MOTHERDUCK_TOKEN=<ma_token_cua_ban>")
        print("5. Chạy lại script này: py scripts/test_motherduck_conn.py")
        print("-" * 70)
        sys.exit(1)

    # Đảm bảo duckdb nhận biến môi trường
    os.environ["motherduck_token"] = token.strip()
    os.environ["MOTHERDUCK_TOKEN"] = token.strip()

    print(f"Tên Database đích  : {db_name}")
    print(f"MotherDuck Token   : {token[:8]}...{token[-4:] if len(token) > 12 else ''} (Đã nạp an toàn)")
    print("-" * 70)
    print("[*] Đang khởi tạo kết nối tới MotherDuck Cloud...")

    try:
        # 3. Kết nối tổng quan để đảm bảo database tồn tại
        init_conn = duckdb.connect(f"md:?motherduck_token={token.strip()}")
        init_conn.execute(f"CREATE DATABASE IF NOT EXISTS {db_name};")
        init_conn.close()

        # 4. Kết nối trực tiếp vào database mục tiêu theo yêu cầu đề bài
        conn = duckdb.connect(f"md:{db_name}?motherduck_token={token.strip()}")

        # 5. Thực thi câu lệnh kiểm tra SELECT 1
        query = "SELECT 1 AS status, CURRENT_DATABASE() AS current_db, VERSION() AS duckdb_version;"
        result = conn.execute(query).fetchone()

        status_code = result[0]
        current_db = result[1]
        duckdb_ver = result[2]

        print("[+] KẾT NỐI MOTHERDUCK THÀNH CÔNG!")
        print("-" * 70)
        print(f"  > Trạng thái query SELECT 1 : {status_code} (SUCCESS)")
        print(f"  > Database đang hoạt động   : {current_db}")
        print(f"  > Phiên bản DuckDB Core     : {duckdb_ver}")
        print("-" * 70)
        print("BẢNG KẾT QUẢ TRUY VẤN MINH CHỨNG:")
        print(f"| {'STATUS':<8} | {'CURRENT_DATABASE':<20} | {'DUCKDB_VERSION':<15} |")
        print(f"|{'-'*10}|{'-'*22}|{'-'*17}|")
        print(f"| {str(status_code):<8} | {str(current_db):<20} | {str(duckdb_ver):<15} |")
        print("-" * 70)
        print(">>> TASK GD3.1 HOÀN TẤT ĐẦY ĐỦ CÁC TIÊU CHÍ NGHIỆM THU <<<")
        print("=" * 70)

        conn.close()
        return 0

    except Exception as e:
        print("\n[X] LỖI KHI KẾT NỐI TỚI MOTHERDUCK:")
        print(f"Chi tiết lỗi: {e}")
        print("\nGợi ý khắc phục:")
        print("- Kiểm tra lại tính chính xác của MotherDuck Token trong file .env.")
        print("- Kiểm tra kết nối mạng internet tới MotherDuck API.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
