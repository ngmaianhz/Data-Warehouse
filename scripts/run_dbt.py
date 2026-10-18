import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# 1. Nạp file .env từ thư mục gốc
ROOT_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = ROOT_DIR / ".env"

if ENV_FILE.exists():
    load_dotenv(ENV_FILE)
else:
    print(f"[!] Cảnh báo: Không tìm thấy file {ENV_FILE}")

# Đảm bảo UTF-8 trên Windows console
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# 2. Thực thi dbt CLI qua dbtRunner
from dbt.cli.main import dbtRunner

dbt = dbtRunner()
args = sys.argv[1:]

# Nếu không truyền project-dir và profiles-dir, mặc định trỏ vào dbt_olist
default_project_dir = str(ROOT_DIR / "dbt_olist")
has_project_dir = any("--project-dir" in arg for arg in args)
has_profiles_dir = any("--profiles-dir" in arg for arg in args)

# Trong dbt CLI / dbtRunner, subcommand (debug, deps, run...) phải đứng trước các flag
subcommand = []
flags = []

for arg in args:
    if not arg.startswith("-") and not subcommand:
        subcommand.append(arg)
    else:
        flags.append(arg)

cli_args = subcommand + flags
if not has_project_dir:
    cli_args.extend(["--project-dir", default_project_dir])
if not has_profiles_dir:
    cli_args.extend(["--profiles-dir", default_project_dir])


print(f"[*] Thực thi dbt với tham số: {' '.join(cli_args)}")
res = dbt.invoke(cli_args)

if res.exception:
    print(f"[X] Ngoại lệ dbt: {res.exception}")
if not res.success:
    sys.exit(1)
