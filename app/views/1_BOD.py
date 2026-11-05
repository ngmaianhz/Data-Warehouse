"""BOD · Tăng trưởng & thị trường — main_gold.fact_sales + dim_date."""

import plotly.graph_objects as go
import streamlit as st

import db
import ui
from db import GOLD

f = ui.header("BOD · Tăng trưởng")
where, params = db.sales_where(f)

m = db.query(f"""
    SELECT (f.purchase_date_key // 100) AS ym, SUM(f.gmv) AS gmv, SUM(f.price) AS revenue,
           SUM(f.freight_value) AS freight, COUNT(DISTINCT f.order_id) AS orders
    FROM {GOLD}.fact_sales f WHERE {where} GROUP BY 1 ORDER BY 1
""", params)
m["month"] = m["ym"].astype(int).map(ui.ym_label)
m["mom_pct"] = 100 * m["gmv"].pct_change()
m["aov"] = m["gmv"] / m["orders"]

dm = db.query(f"""
    SELECT d.year, d.month, d.quarter, SUM(f.gmv) AS gmv, SUM(f.price) AS revenue, SUM(f.freight_value) AS freight,
           COUNT(DISTINCT f.order_id) AS orders
    FROM {GOLD}.fact_sales f JOIN {GOLD}.dim_date d ON d.date_key = f.purchase_date_key
    WHERE {where} GROUP BY 1, 2, 3 ORDER BY 1, 2
""", params)
piv = dm.pivot(index="month", columns="year", values="gmv")
yoy = None
if {2017, 2018}.issubset(piv.columns):
    both = piv[[2017, 2018]].dropna()
    if len(both):
        yoy = 100 * (both[2018].sum() / both[2017].sum() - 1)

s = db.query(f"""
    SELECT f.shipping_state AS state, SUM(f.gmv) AS gmv, COUNT(DISTINCT f.order_id) AS orders,
           SUM(f.gmv) / COUNT(DISTINCT f.order_id) AS aov, 100 * SUM(f.freight_value) / SUM(f.gmv) AS freight_pct
    FROM {GOLD}.fact_sales f WHERE {where} GROUP BY 1 ORDER BY 2 DESC
""", params)
s["cum_share"] = 100 * s["gmv"].cumsum() / s["gmv"].sum()

tot_gmv, tot_orders = m["gmv"].sum(), m["orders"].sum()
best = m.loc[m["gmv"].idxmax()] if len(m) else None
ui.kpis([
    ("Delivered GMV", ui.brl(tot_gmv), f"{len(m)} tháng"),
    ("Số đơn delivered", ui.num(tot_orders), None),
    ("AOV", ui.brl(tot_gmv / tot_orders if tot_orders else None), None),
    ("GMV 2018 vs 2017", f"{yoy:+.1f}%" if yoy is not None else "–", "các tháng có cả 2 năm"),
    ("Tháng GMV cao nhất", best.month if best is not None else "–", ui.brl(best.gmv) if best is not None else None),
    ("Bang tạo 80% GMV", f"{int((s['cum_share'] < 80).sum()) + 1 if len(s) else 0}/{len(s)}", "bang"),
    ("Cước / GMV", ui.pct(100 * m["freight"].sum() / tot_gmv if tot_gmv else None), None),
])

c1, c2 = st.columns([1.7, 1])
with c1:
    fig = go.Figure()
    fig.add_bar(x=m["month"], y=m["gmv"], name="GMV", marker_color=ui.PRIMARY)
    fig.add_scatter(x=m["month"], y=m["mom_pct"], name="MoM %", yaxis="y2", mode="lines+markers",
                    line=dict(color=ui.ACCENT, width=2), marker_size=4)
    fig.update_layout(title="GMV theo tháng và tăng trưởng MoM", yaxis=dict(title="GMV (BRL)"),
                      yaxis2=dict(overlaying="y", side="right", showgrid=False, ticksuffix="%", zeroline=True,
                                  zerolinecolor="#E2E8F0"))
    ui.tile(fig)
with c2:
    fig = go.Figure()
    palette = {2016: ui.MUTED, 2017: ui.SEQ[2], 2018: ui.ACCENT}
    for y, g in dm.groupby("year"):
        g = g.groupby("month", as_index=False)["gmv"].sum()
        fig.add_scatter(x=g["month"], y=g["gmv"], name=str(y), mode="lines+markers",
                        line=dict(color=palette.get(int(y), ui.PRIMARY), width=2), marker_size=5)
    fig.update_layout(title="So sánh GMV cùng tháng giữa các năm", xaxis=dict(dtick=1, title="Tháng"))
    ui.tile(fig)

q = dm.groupby(["year", "quarter"], as_index=False)[["gmv", "revenue", "freight", "orders"]].sum()
q["label"] = q["year"].astype(str) + "-Q" + q["quarter"].astype(str)
q["months"] = dm.groupby(["year", "quarter"])["month"].nunique().values
w = db.query(f"""
    SELECT d.day_of_week, d.day_name, d.is_weekend, COUNT(DISTINCT f.order_id) AS orders, SUM(f.gmv) AS gmv
    FROM {GOLD}.fact_sales f JOIN {GOLD}.dim_date d ON d.date_key = f.purchase_date_key
    WHERE {where} GROUP BY 1, 2, 3 ORDER BY 1
""", params)

c1, c2, c3 = st.columns([1, 1.45, 0.85])
with c1:
    fig = go.Figure()
    fig.add_bar(x=q["label"], y=q["revenue"], name="Doanh thu thuần", marker_color=ui.PRIMARY)
    fig.add_bar(x=q["label"], y=q["freight"], name="Cước", marker_color=ui.SEQ[1])
    fig.update_layout(title="GMV theo quý", barmode="stack")
    ui.tile(fig)
with c2:
    fig = go.Figure()
    fig.add_bar(x=s["state"], y=s["gmv"], name="GMV", marker_color=ui.PRIMARY)
    fig.add_scatter(x=s["state"], y=s["cum_share"], name="% lũy kế", yaxis="y2", mode="lines",
                    line=dict(color=ui.BAD, width=2))
    fig.add_hline(y=80, yref="y2", line_dash="dot", line_color=ui.MUTED)
    fig.update_layout(title="Pareto GMV theo bang giao hàng", xaxis=dict(tickfont_size=9),
                      yaxis2=dict(overlaying="y", side="right", range=[0, 105], showgrid=False, ticksuffix="%"))
    ui.tile(fig)
with c3:
    fig = go.Figure(go.Bar(x=w["day_name"].str[:3], y=w["orders"],
                           marker_color=[ui.ACCENT if x else ui.PRIMARY for x in w["is_weekend"]]))
    fig.update_layout(title="Số đơn theo thứ (cam = cuối tuần)")
    ui.tile(fig)

ui.register(m[["month", "gmv", "revenue", "freight", "orders", "aov", "mom_pct"]], "bod_monthly", "GMV theo tháng")
ui.register(dm, "bod_year_month", "GMV theo năm × tháng")
ui.register(q, "bod_quarterly", "GMV theo quý")
ui.register(s, "bod_states", "GMV theo bang")
ui.register(w, "bod_weekday", "Đơn theo thứ")
ui.footer([f"{GOLD}.fact_sales", f"{GOLD}.dim_date"])
