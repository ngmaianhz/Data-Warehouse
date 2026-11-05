"""
Olist CRM Dashboard (GD5.1): file điều hướng.

Chạy ở thư mục gốc repo:
    streamlit run app/01_app_dashboard.py      (hoặc nhấp đúp run_dashboard.bat)

Vị trí trong kiến trúc nhóm: tầng Application. Dashboard chỉ đọc Core Data Warehouse (main_gold, Star Schema)
và Customer Data Mart (main_mart, gồm kết quả K-Means ghi ngược về Mart) trên MotherDuck, không đọc Bronze/Silver.
Mỗi trang thiết kế vừa 1 màn hình ngang 16:9.
"""

import streamlit as st

st.set_page_config(page_title="Olist CRM Dashboard", page_icon="📊", layout="wide", initial_sidebar_state="collapsed")

nav = st.navigation([
    st.Page("views/0_Overview.py", title="Tổng quan", icon="🏠", default=True),
    st.Page("views/1_BOD.py", title="BOD · Tăng trưởng", icon="📈"),
    st.Page("views/2_Marketing.py", title="Marketing · Khách hàng", icon="🎯"),
    st.Page("views/3_Sales.py", title="Sales · Ngành hàng", icon="🛒"),
    st.Page("views/4_Logistics.py", title="Logistics · Giao vận", icon="🚚"),
], position="top")
nav.run()
