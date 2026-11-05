"""Logistics · Giao vận — lead time từ date key (dim_date), tỷ lệ trễ từ mart_customer_360."""

import plotly.graph_objects as go
import streamlit as st

import db
import ui
from db import GOLD, MART

f = ui.header("Logistics · Giao vận")
where, params = db.sales_where(f)
cw, cp = db.customer_where(f, "c")

# Cấp đơn hàng: lead time = ngày giao thực tế − ngày đặt (bỏ đơn delivered_date_key = −1)
ORDERS = f"""
    WITH o AS (
        SELECT f.order_id, ANY_VALUE(f.shipping_state) AS ship_state, ANY_VALUE(f.seller_id) AS seller_id,
               ANY_VALUE(f.purchase_date_key) AS pk, ANY_VALUE(f.delivered_date_key) AS dk,
               SUM(f.freight_value) AS freight, SUM(f.gmv) AS gmv
        FROM {GOLD}.fact_sales f WHERE {where} AND f.delivered_date_key <> -1 GROUP BY 1
    ), ol AS (
        SELECT o.*, date_diff('day', dp.date_day, dd.date_day) AS lead_days
        FROM o JOIN {GOLD}.dim_date dp ON dp.date_key = o.pk JOIN {GOLD}.dim_date dd ON dd.date_key = o.dk
    )
"""
k = db.query(ORDERS + """
    SELECT COUNT(*) AS orders, median(lead_days) AS med, AVG(lead_days) AS avg, quantile_cont(lead_days, 0.9) AS p90,
           100 * AVG(CASE WHEN lead_days > 30 THEN 1 ELSE 0 END) AS over30, 100 * SUM(freight) / SUM(gmv) AS freight_pct
    FROM ol
""", params).iloc[0]
late = db.query(f"""
    SELECT 100 * SUM(c.orders_late) / NULLIF(SUM(c.orders_late + c.orders_on_time), 0) AS late_rate
    FROM {MART}.mart_customer_360 c WHERE {cw}
""", cp).iloc[0, 0]
ui.kpis([
    ("Đơn đã giao", ui.num(k.orders), None),
    ("Lead time trung vị", f"{ui.num(k.med)} ngày", "ngày giao − ngày đặt"),
    ("Lead time TB", f"{ui.num(k.avg, 1)} ngày", None),
    ("P90 lead time", f"{ui.num(k.p90)} ngày", "10% đơn chậm nhất"),
    ("Đơn giao > 30 ngày", ui.pct(k.over30), None),
    ("Tỷ lệ giao trễ", ui.pct(late), "so với ngày dự kiến · Mart 360"),
    ("Cước / GMV", ui.pct(k.freight_pct), None),
])

# --- Hàng 1 --------------------------------------------------------------------------------------
lt = db.query(ORDERS + """
    SELECT pk // 100 AS ym, AVG(lead_days) AS avg_lead, median(lead_days) AS med_lead, COUNT(*) AS orders
    FROM ol GROUP BY 1 ORDER BY 1
""", params)
lt["month"] = lt["ym"].astype(int).map(ui.ym_label)
dist = db.query(ORDERS + "SELECT LEAST(lead_days, 60) AS days, COUNT(*) AS orders FROM ol GROUP BY 1 ORDER BY 1", params)
by_state = db.query(ORDERS + """
    SELECT ship_state AS state, COUNT(*) AS orders, AVG(lead_days) AS avg_lead, 100 * SUM(freight) / SUM(gmv) AS freight_pct
    FROM ol GROUP BY 1
""", params)
late_state = db.query(f"""
    SELECT c.latest_state AS state, AVG(c.avg_review_score) AS avg_review,
           100 * SUM(c.orders_late) / NULLIF(SUM(c.orders_late + c.orders_on_time), 0) AS late_rate
    FROM {MART}.mart_customer_360 c WHERE {cw} GROUP BY 1
""", cp)
st_df = by_state.merge(late_state, on="state", how="left").sort_values("avg_lead", ascending=False)

c1, c2, c3 = st.columns([1.2, 0.95, 1.25])
with c1:
    fig = go.Figure()
    fig.add_scatter(x=lt["month"], y=lt["avg_lead"], name="Trung bình", mode="lines+markers",
                    line=dict(color=ui.PRIMARY, width=2), marker_size=4)
    fig.add_scatter(x=lt["month"], y=lt["med_lead"], name="Trung vị", mode="lines", line=dict(color=ui.ACCENT, dash="dot"))
    fig.update_layout(title="Lead time theo tháng đặt mua (ngày)")
    ui.tile(fig)
with c2:
    fig = go.Figure(go.Bar(x=dist["days"], y=dist["orders"],
                           marker_color=[ui.BAD if d > 30 else ui.SEQ[3] for d in dist["days"]]))
    fig.update_layout(title="Phân phối lead time (≥ 60 gộp)", bargap=0.05, xaxis=dict(title="Ngày"))
    ui.tile(fig)
with c3:
    fig = go.Figure()
    fig.add_bar(x=st_df["state"], y=st_df["avg_lead"], name="Lead time TB", marker_color=ui.SEQ[3])
    fig.add_scatter(x=st_df["state"], y=st_df["late_rate"], name="% trễ", yaxis="y2", mode="markers",
                    marker=dict(color=ui.BAD, size=6))
    fig.update_layout(title="Lead time TB và % trễ theo bang khách", xaxis=dict(tickfont_size=8),
                      yaxis2=dict(overlaying="y", side="right", showgrid=False, ticksuffix="%"))
    ui.tile(fig)

# --- Hàng 2 --------------------------------------------------------------------------------------
routes = db.query(ORDERS + f"""
    SELECT s.seller_state, ol.ship_state, COUNT(*) AS orders, AVG(lead_days) AS avg_lead
    FROM ol JOIN {GOLD}.dim_seller s USING (seller_id) GROUP BY 1, 2
""", params)
top_seller = routes.groupby("seller_state")["orders"].sum().nlargest(7).index.tolist()
top_ship = routes.groupby("ship_state")["orders"].sum().nlargest(14).index.tolist()
r = routes[routes["seller_state"].isin(top_seller) & routes["ship_state"].isin(top_ship) & (routes["orders"] >= 20)]
mat = r.pivot(index="seller_state", columns="ship_state", values="avg_lead").reindex(index=top_seller, columns=top_ship)
rv = db.query(ORDERS + f"""
    , b AS (
        SELECT CASE WHEN lead_days <= 7 THEN 1 WHEN lead_days <= 14 THEN 2 WHEN lead_days <= 21 THEN 3
                    WHEN lead_days <= 30 THEN 4 ELSE 5 END AS o, r.review_score
        FROM ol JOIN {GOLD}.fact_customer_reviews r USING (order_id)
    )
    SELECT o, COUNT(*) AS reviews, AVG(review_score) AS avg_review,
           100 * AVG(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) AS low_pct,
           100 * AVG(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) AS five_pct
    FROM b GROUP BY 1 ORDER BY 1
""", params)
rv["bucket"] = rv["o"].map({1: "0–7", 2: "8–14", 3: "15–21", 4: "22–30", 5: ">30"})
rdist = db.query(f"""
    SELECT r.review_score, COUNT(*) AS reviews FROM {GOLD}.fact_customer_reviews r
    WHERE r.order_id IN (SELECT f.order_id FROM {GOLD}.fact_sales f WHERE {where}) GROUP BY 1 ORDER BY 1
""", params)

c1, c2, c3 = st.columns([1.55, 1.05, 0.8])
with c1:
    fig = go.Figure(go.Heatmap(z=mat.values, x=mat.columns, y=mat.index, colorscale="Reds",
                               text=mat.round(1).astype(object).where(mat.notna(), "").values,
                               texttemplate="%{text}", textfont_size=9, hoverongaps=False,
                               colorbar=dict(thickness=8, title="ngày")))
    fig.update_layout(title="Lead time TB theo tuyến: bang seller (dọc) → bang khách (ngang), ≥ 20 đơn",
                      yaxis=dict(autorange="reversed"))
    ui.tile(fig)
with c2:
    fig = go.Figure()
    fig.add_bar(x=rv["bucket"], y=rv["low_pct"], name="% 1–2★", marker_color=ui.BAD)
    fig.add_bar(x=rv["bucket"], y=rv["five_pct"], name="% 5★", marker_color=ui.GOOD)
    fig.add_scatter(x=rv["bucket"], y=rv["avg_review"], name="Review TB", yaxis="y2", mode="lines+markers",
                    line=dict(color="#0F172A", width=2))
    fig.update_layout(title="Review theo nhóm lead time (ngày)", barmode="group", yaxis=dict(ticksuffix="%"),
                      yaxis2=dict(overlaying="y", side="right", range=[1, 5], showgrid=False))
    ui.tile(fig)
with c3:
    fig = go.Figure(go.Bar(x=rdist["review_score"].astype(int).astype(str) + "★", y=rdist["reviews"],
                           marker_color=[ui.BAD, "#F87171", ui.MUTED, "#86EFAC", ui.GOOD][:len(rdist)]))
    fig.update_layout(title="Phân phối điểm review")
    ui.tile(fig)

ui.register(lt, "log_monthly_lead", "Lead time theo tháng")
ui.register(dist, "log_lead_distribution", "Phân phối lead time")
ui.register(st_df, "log_state", "Lead time & % trễ theo bang")
ui.register(routes.sort_values("orders", ascending=False), "log_routes", "Tuyến seller → khách")
ui.register(rv.drop(columns="o"), "log_review_by_lead", "Review theo nhóm lead time")
ui.register(rdist, "log_review_distribution", "Phân phối review")
ui.footer([f"{GOLD}.fact_sales", f"{GOLD}.dim_date", f"{GOLD}.dim_seller", f"{GOLD}.fact_customer_reviews",
           f"{MART}.mart_customer_360"])
