"""Tổng quan KPI — fact_sales, fact_customer_reviews, Customer Mart, obs_pipeline_health."""

import pandas as pd
import plotly.graph_objects as go
import streamlit as st

import db
import ui
from db import GOLD, MART

f = ui.header("Tổng quan")
where, params = db.sales_where(f)

KPI_SQL = f"""
    WITH s AS (SELECT * FROM {GOLD}.fact_sales f WHERE {{w}})
    SELECT SUM(gmv) AS gmv, SUM(price) AS revenue, COUNT(DISTINCT order_id) AS orders,
           COUNT(DISTINCT customer_unique_id) AS customers,
           (SELECT AVG(r.review_score) FROM {GOLD}.fact_customer_reviews r
             WHERE r.order_id IN (SELECT order_id FROM s)) AS avg_review
    FROM s
"""
cur = db.query(KPI_SQL.format(w=where), params).iloc[0]
prev_f = dict(f, date_from=f["date_from"] - 10000, date_to=f["date_to"] - 10000)
# Năm 2016 chỉ có vài tháng dữ liệu thưa: không so cùng kỳ khi kỳ trước rơi vào 2016
if prev_f["date_from"] >= 20170101:
    pw, pp = db.sales_where(prev_f)
    prev = db.query(KPI_SQL.format(w=pw), pp).iloc[0]
else:
    prev = pd.Series({k: float("nan") for k in cur.index})


def yoy(a, b):
    return None if b is None or pd.isna(b) or b == 0 else 100 * (a / b - 1)


aov = cur.gmv / cur.orders if cur.orders else None
aov_p = prev.gmv / prev.orders if prev.orders and not pd.isna(prev.orders) else None
sub = "so với cùng kỳ" if not pd.isna(prev.gmv) else "đơn delivered"
ui.kpis([
    ("Delivered GMV", ui.brl(cur.gmv), sub, yoy(cur.gmv, prev.gmv)),
    ("Doanh thu thuần (price)", ui.brl(cur.revenue), sub, yoy(cur.revenue, prev.revenue)),
    ("Số đơn delivered", ui.num(cur.orders), sub, yoy(cur.orders, prev.orders)),
    ("AOV", ui.brl(aov), sub, yoy(aov, aov_p)),
    ("Khách hàng", ui.num(cur.customers), sub, yoy(cur.customers, prev.customers)),
    ("Điểm review TB", ui.num(cur.avg_review, 2), "thang 1–5", None),
])

# --- Hàng 1 --------------------------------------------------------------------------------------
monthly = db.query(f"""
    SELECT (f.purchase_date_key // 100) AS ym, SUM(f.gmv) AS gmv, COUNT(DISTINCT f.order_id) AS orders,
           COUNT(DISTINCT f.customer_unique_id) AS customers
    FROM {GOLD}.fact_sales f WHERE {where} GROUP BY 1 ORDER BY 1
""", params)
monthly["month"] = monthly["ym"].astype(int).map(ui.ym_label)
monthly["aov"] = monthly["gmv"] / monthly["orders"]
states = db.query(f"""
    SELECT f.shipping_state AS state, SUM(f.gmv) AS gmv, COUNT(DISTINCT f.order_id) AS orders
    FROM {GOLD}.fact_sales f WHERE {where} GROUP BY 1 ORDER BY 2 DESC
""", params)
states["share"] = 100 * states["gmv"] / states["gmv"].sum()

c1, c2 = st.columns([2.1, 1])
with c1:
    fig = go.Figure()
    fig.add_bar(x=monthly["month"], y=monthly["gmv"], name="GMV", marker_color=ui.PRIMARY, opacity=0.9)
    fig.add_scatter(x=monthly["month"], y=monthly["orders"], name="Số đơn", yaxis="y2", mode="lines+markers",
                    line=dict(color=ui.ACCENT, width=2), marker_size=4)
    fig.update_layout(title="GMV và số đơn theo tháng", yaxis=dict(title="GMV (BRL)"),
                      yaxis2=dict(title="Số đơn", overlaying="y", side="right", showgrid=False))
    ui.tile(fig)
with c2:
    top = states.head(10).iloc[::-1]
    fig = go.Figure(go.Bar(x=top["share"], y=top["state"], orientation="h", marker_color=ui.SEQ[3],
                           text=top["share"].map(lambda v: f"{v:.1f}%"), textposition="outside", cliponaxis=False))
    fig.update_layout(title="Top 10 bang theo % GMV", xaxis=dict(visible=False, range=[0, top["share"].max() * 1.25]))
    ui.tile(fig)

# --- Hàng 2 --------------------------------------------------------------------------------------
cw, cp = db.customer_where(f, "c")
clusters = db.query(f"""
    SELECT d.cluster_id, d.cluster_label, COUNT(*) AS customers, SUM(r.monetary) AS monetary
    FROM {MART}.mart_customer_rfm r
    JOIN {MART}.dim_customer_cluster d USING (cluster_id)
    JOIN {MART}.mart_customer_360 c USING (customer_unique_id)
    WHERE {cw} AND r.cluster_id <> -1 GROUP BY 1, 2 ORDER BY 1
""", cp)
clusters["pct_customers"] = 100 * clusters["customers"] / clusters["customers"].sum()
clusters["pct_monetary"] = 100 * clusters["monetary"] / clusters["monetary"].sum()
pay = db.query(f"""
    SELECT COALESCE(p.payment_type_name_vi, p.payment_type) AS payment, COUNT(DISTINCT f.order_id) AS orders,
           SUM(f.gmv) AS gmv
    FROM {GOLD}.fact_sales f JOIN {GOLD}.dim_payment_type p ON p.payment_type_key = f.primary_payment_type_key
    WHERE {where} GROUP BY 1 ORDER BY 2 DESC
""", params)
health = db.query(f"""
    SELECT pipeline_layer AS layer, health_status AS status, COUNT(*) AS checks
    FROM {MART}.obs_pipeline_health GROUP BY 1, 2
""")

c1, c2, c3 = st.columns([1.3, 1, 1])
with c1:
    fig = go.Figure()
    fig.add_bar(y=clusters["cluster_label"], x=clusters["pct_customers"], name="% khách", orientation="h",
                marker_color=ui.MUTED, text=clusters["pct_customers"].map(lambda v: f"{v:.1f}%"),
                textposition="outside", cliponaxis=False)
    fig.add_bar(y=clusters["cluster_label"], x=clusters["pct_monetary"], name="% chi tiêu", orientation="h",
                marker_color=ui.PRIMARY, text=clusters["pct_monetary"].map(lambda v: f"{v:.1f}%"),
                textposition="outside", cliponaxis=False)
    fig.update_layout(title="Cụm K-Means: % khách vs % chi tiêu", barmode="group",
                      yaxis=dict(autorange="reversed"), xaxis=dict(visible=False,
                      range=[0, max(clusters["pct_customers"].max(), clusters["pct_monetary"].max()) * 1.25]))
    ui.tile(fig)
with c2:
    fig = go.Figure(go.Pie(labels=pay["payment"], values=pay["orders"], hole=0.6, sort=False, textinfo="percent",
                           marker=dict(colors=[ui.PRIMARY, ui.ACCENT, ui.GOOD, ui.SEQ[1], ui.MUTED, ui.BAD])))
    fig.update_layout(title="Đơn theo phương thức thanh toán",
                      legend=dict(orientation="v", x=1.0, xanchor="left", y=0.5, yanchor="middle"))
    ui.tile(fig)
with c3:
    order = ["BRONZE", "SILVER", "GOLD", "MART"]
    color = {"PASS": ui.GOOD, "OK": ui.GOOD, "WARN": ui.ACCENT, "FAIL": ui.BAD}
    fig = go.Figure()
    for status in ["PASS", "OK", "WARN", "FAIL"] + sorted(set(health["status"]) - {"PASS", "OK", "WARN", "FAIL"}):
        g = health[health["status"] == status].set_index("layer").reindex(order)
        if g["checks"].notna().any():
            fig.add_bar(x=order, y=g["checks"], name=status, marker_color=color.get(status, ui.MUTED))
    passed = health.loc[health["status"].isin(["PASS", "OK"]), "checks"].sum()
    fig.update_layout(title=f"Data Observability · {passed}/{health['checks'].sum()} đạt", barmode="stack")
    ui.tile(fig)

ui.register(monthly[["month", "gmv", "orders", "customers", "aov"]], "overview_monthly", "GMV & đơn theo tháng")
ui.register(states, "overview_states", "GMV theo bang")
ui.register(clusters, "overview_clusters", "Cụm khách hàng")
ui.register(pay, "overview_payment", "Phương thức thanh toán")
ui.register(health, "overview_observability", "Data Observability")
ui.footer([f"{GOLD}.fact_sales", f"{GOLD}.fact_customer_reviews", f"{GOLD}.dim_payment_type",
           f"{MART}.mart_customer_rfm", f"{MART}.dim_customer_cluster", f"{MART}.obs_pipeline_health"])
