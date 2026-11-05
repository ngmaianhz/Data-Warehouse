"""
Kết nối MotherDuck và các hàm truy vấn dùng chung cho dashboard.

Nguyên tắc (GD5.1):
- Token đọc từ st.secrets["MOTHERDUCK_TOKEN"] (.streamlit/secrets.toml, không commit);
  khi chạy local có thể lấy từ biến môi trường / file .env của repo.
- Một kết nối duy nhất (@st.cache_resource), kết quả truy vấn cache 1 giờ (@st.cache_data).
- Mọi bộ lọc truyền bằng tham số (?), không ghép chuỗi giá trị vào SQL.
- GROUP BY chạy trong MotherDuck, Streamlit chỉ nhận kết quả đã tổng hợp.
"""

import os
from pathlib import Path

import duckdb
import pandas as pd
import streamlit as st

DB_NAME = "olist_warehouse"

# Tên schema thực tế trên MotherDuck (dbt-duckdb thêm tiền tố "main_")
GOLD = "main_gold"
MART = "main_mart"
ML = "ml"

# Rule dùng chung (phải trùng với SQL đối soát GD5.2)
DELIVERED = "f.order_status = 'delivered'"


def _get_token() -> str | None:
    try:
        if "MOTHERDUCK_TOKEN" in st.secrets:
            return st.secrets["MOTHERDUCK_TOKEN"]
    except Exception:
        pass
    token = os.getenv("MOTHERDUCK_TOKEN")
    if token:
        return token
    env_file = Path(__file__).resolve().parent.parent / ".env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("MOTHERDUCK_TOKEN="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return None


@st.cache_resource(show_spinner="Đang kết nối MotherDuck…")
def get_connection() -> duckdb.DuckDBPyConnection:
    test_db = os.getenv("DASHBOARD_TEST_DUCKDB")  # chỉ dùng khi kiểm thử giao diện với dữ liệu giả
    if test_db:
        return duckdb.connect(test_db, read_only=True)
    token = _get_token()
    if not token:
        st.error("Chưa có MOTHERDUCK_TOKEN. Tạo file .streamlit/secrets.toml theo mẫu secrets.toml.example.")
        st.stop()
    return duckdb.connect(f"md:{DB_NAME}?motherduck_token={token}")


@st.cache_data(ttl=3600, show_spinner=False)
def query(sql: str, params: tuple = ()) -> pd.DataFrame:
    con = get_connection().cursor()  # cursor riêng cho mỗi lượt chạy, an toàn khi nhiều người xem cùng lúc
    return con.execute(sql, [list(p) if isinstance(p, tuple) else p for p in params]).df()


# ---------------------------------------------------------------------------
# Bộ lọc dùng chung cho fact_sales (alias f)
# ---------------------------------------------------------------------------
def sales_where(filters: dict, alias: str = "f", delivered_only: bool = True) -> tuple[str, tuple]:
    """WHERE cho fact_sales theo khoảng tháng đặt mua và bang giao hàng."""
    clauses, params = [], []
    if delivered_only:
        clauses.append(f"{alias}.order_status = 'delivered'")
    clauses.append(f"{alias}.purchase_date_key BETWEEN ? AND ?")
    params += [filters["date_from"], filters["date_to"]]
    if filters.get("states"):
        clauses.append(f"list_contains(?, {alias}.shipping_state)")
        params.append(tuple(filters["states"]))
    return " AND ".join(clauses), tuple(params)


def customer_where(filters: dict, alias: str = "c") -> tuple[str, tuple]:
    """WHERE cho các bảng cấp khách hàng (lọc theo bang hiện tại của khách)."""
    if filters.get("states"):
        return f"list_contains(?, {alias}.latest_state)", (tuple(filters["states"]),)
    return "TRUE", ()


@st.cache_data(ttl=3600, show_spinner=False)
def available_months() -> list[int]:
    df = query(f"""
        SELECT DISTINCT (purchase_date_key // 100) AS ym
        FROM {GOLD}.fact_sales
        WHERE order_status = 'delivered' AND purchase_date_key > 0
        ORDER BY 1
    """)
    return df["ym"].astype(int).tolist()


@st.cache_data(ttl=3600, show_spinner=False)
def available_states() -> list[str]:
    df = query(f"SELECT DISTINCT shipping_state FROM {GOLD}.fact_sales WHERE shipping_state IS NOT NULL ORDER BY 1")
    return df["shipping_state"].tolist()
