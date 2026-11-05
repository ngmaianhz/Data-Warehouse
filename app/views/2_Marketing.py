"""Marketing · Khách hàng — Customer Data Mart + kết quả K-Means (In-Database ML)."""

import plotly.graph_objects as go
import streamlit as st

import db
import ui
from db import MART

profile = db.query(f"""
    SELECT cluster_id, cluster_label, cluster_description, n_customers, pct_customers, pct_monetary,
           median_recency_days, mean_frequency, repeat_rate, median_monetary, avg_review_score, late_order_rate, top_state
    FROM {MART}.dim_customer_cluster WHERE cluster_id <> -1 ORDER BY cluster_id
""")
labels = dict(zip(profile["cluster_id"].astype(int), profile["cluster_label"]))


def cluster_filter(col):
    return col.multiselect("Cụm khách hàng", list(labels.values()), key="f_clusters", placeholder="Tất cả cụm")


f = ui.header("Marketing · Khách hàng", extra=cluster_filter)
cw, cp = db.customer_where(f, "c")
chosen = f["extra"] or list(labels.values())
ids = tuple(k for k, v in labels.items() if v in chosen)
W = f"{cw} AND list_contains(?, r.cluster_id)"
P = cp + (ids,)
BASE = f"FROM {MART}.mart_customer_rfm r JOIN {MART}.mart_customer_360 c USING (customer_unique_id)"

k = db.query(f"""
    SELECT COUNT(*) AS customers, 100 * AVG(CASE WHEN c.total_orders > 1 THEN 1 ELSE 0 END) AS repeat_rate,
           AVG(c.total_gmv) AS clv, median(r.recency_days) AS med_recency, AVG(c.avg_review_score) AS review,
           100 * SUM(c.orders_late) / NULLIF(SUM(c.orders_late + c.orders_on_time), 0) AS late_rate,
           SUM(CASE WHEN (year(c.first_order_date) * 10000 + month(c.first_order_date) * 100 + day(c.first_order_date))
                         BETWEEN ? AND ? THEN 1 ELSE 0 END) AS new_customers
    {BASE} WHERE {W}
""", (f["date_from"], f["date_to"]) + P).iloc[0]
ui.kpis([
    ("Khách hàng", ui.num(k.customers), "theo bộ lọc bang và cụm"),
    ("Khách mới trong kỳ", ui.num(k.new_customers), f["label"]),
    ("Tỷ lệ mua lặp", ui.pct(k.repeat_rate), "khách có ≥ 2 đơn"),
    ("Chi tiêu TB / khách", ui.brl(k.clv), "CLV lịch sử"),
    ("Recency trung vị", f"{ui.num(k.med_recency)} ngày", None),
    ("Review TB", ui.num(k.review, 2), None),
    ("Tỷ lệ giao trễ", ui.pct(k.late_rate), None),
])

# --- Hàng 1 --------------------------------------------------------------------------------------
seg = db.query(f"""
    SELECT r.cluster_id, COUNT(*) AS customers, SUM(r.monetary) AS monetary, median(r.recency_days) AS med_recency,
           AVG(r.frequency) AS avg_frequency, median(r.monetary) AS med_monetary
    {BASE} WHERE {W} GROUP BY 1 ORDER BY 1
""", P)
seg["cluster"] = seg["cluster_id"].map(labels)
seg["pct_customers"] = 100 * seg["customers"] / seg["customers"].sum()
seg["pct_monetary"] = 100 * seg["monetary"] / seg["monetary"].sum()
sample = db.query(f"""
    SELECT * FROM (SELECT r.cluster_id, r.recency_days, r.frequency, r.monetary {BASE} WHERE {W})
    USING SAMPLE reservoir(3000 ROWS) REPEATABLE (42)
""", P)
hist = db.query(f"""
    SELECT r.cluster_id, (r.recency_days // 30) * 30 AS bin, COUNT(*) AS customers
    {BASE} WHERE {W} GROUP BY 1, 2 ORDER BY 2
""", P)

c1, c2, c3 = st.columns([1, 1.35, 1])
with c1:
    fig = go.Figure()
    fig.add_bar(y=seg["cluster"], x=seg["pct_customers"], name="% khách", orientation="h", marker_color=ui.MUTED,
                text=seg["pct_customers"].map(lambda v: f"{v:.1f}%"), textposition="outside", cliponaxis=False)
    fig.add_bar(y=seg["cluster"], x=seg["pct_monetary"], name="% chi tiêu", orientation="h",
                marker_color=[ui.CLUSTER_COLORS.get(c) for c in seg["cluster_id"]],
                text=seg["pct_monetary"].map(lambda v: f"{v:.1f}%"), textposition="outside", cliponaxis=False)
    fig.update_layout(title="Cụm: % khách vs % chi tiêu", barmode="group", yaxis=dict(autorange="reversed"),
                      xaxis=dict(visible=False, range=[0, max(seg["pct_customers"].max(), seg["pct_monetary"].max()) * 1.3]),
                      showlegend=False)
    ui.tile(fig)
with c2:
    fig = go.Figure()
    for cid, g in sample.groupby("cluster_id"):
        fig.add_scatter(x=g["recency_days"], y=g["monetary"], mode="markers", name=labels[cid],
                        marker=dict(color=ui.CLUSTER_COLORS.get(cid), opacity=0.5,
                                    size=4 + 3 * (g["frequency"] - 1).clip(0, 4)))
    fig.update_layout(title="Recency × Monetary (mẫu 3.000 khách)", xaxis=dict(title="Recency (ngày)"),
                      yaxis=dict(title="Monetary (log)", type="log", dtick=1), legend=dict(font_size=9))
    ui.tile(fig)
with c3:
    fig = go.Figure()
    for cid, g in hist.groupby("cluster_id"):
        fig.add_bar(x=g["bin"], y=g["customers"], name=labels[cid], marker_color=ui.CLUSTER_COLORS.get(cid))
    fig.update_layout(title="Phân phối recency (bin 30 ngày)", barmode="stack", bargap=0.05, showlegend=False,
                      xaxis=dict(title="Ngày"))
    ui.tile(fig)

# --- Hàng 2 --------------------------------------------------------------------------------------
geo = db.query(f"SELECT c.latest_state AS state, r.cluster_id, COUNT(*) AS customers {BASE} WHERE {W} GROUP BY 1, 2", P)
tot = geo.groupby("state")["customers"].sum().sort_values(ascending=False)
top_states = tot.head(10).index.tolist()
exp = db.query(f"""
    SELECT r.cluster_id, AVG(c.avg_review_score) AS avg_review,
           100 * SUM(c.orders_late) / NULLIF(SUM(c.orders_late + c.orders_on_time), 0) AS late_rate,
           AVG(c.avg_lead_time_days) AS lead_time
    {BASE} WHERE {W} GROUP BY 1 ORDER BY 1
""", P)
new = db.query(f"""
    SELECT (year(c.first_order_date) * 100 + month(c.first_order_date)) AS ym, COUNT(*) AS new_customers
    {BASE} WHERE {W} AND (year(c.first_order_date) * 10000 + month(c.first_order_date) * 100 + day(c.first_order_date))
          BETWEEN ? AND ? GROUP BY 1 ORDER BY 1
""", P + (f["date_from"], f["date_to"]))
new["month"] = new["ym"].astype(int).map(ui.ym_label)
rep = db.query(f"""
    SELECT CASE WHEN c.total_orders >= 4 THEN '4+' ELSE CAST(c.total_orders AS VARCHAR) END AS orders_bucket,
           COUNT(*) AS customers, SUM(c.total_gmv) AS gmv
    {BASE} WHERE {W} GROUP BY 1 ORDER BY 1
""", P)
rep["pct_customers"] = 100 * rep["customers"] / rep["customers"].sum()
rep["pct_gmv"] = 100 * rep["gmv"] / rep["gmv"].sum()

c1, c2, c3, c4 = st.columns([1.25, 0.95, 1.15, 0.8])
with c1:
    fig = go.Figure()
    for cid, g in geo[geo["state"].isin(top_states)].groupby("cluster_id"):
        g = g.set_index("state").reindex(top_states)
        fig.add_bar(x=top_states, y=100 * g["customers"] / tot[top_states], name=labels[cid],
                    marker_color=ui.CLUSTER_COLORS.get(cid))
    fig.update_layout(title="Cơ cấu cụm trong 10 bang đông khách", barmode="stack", showlegend=False,
                      yaxis=dict(ticksuffix="%", range=[0, 100]))
    ui.tile(fig)
with c2:
    fig = go.Figure()
    fig.add_bar(x=exp["cluster_id"].map(lambda c: f"C{c}"), y=exp["late_rate"], name="% trễ",
                marker_color=[ui.CLUSTER_COLORS.get(c) for c in exp["cluster_id"]])
    fig.add_scatter(x=exp["cluster_id"].map(lambda c: f"C{c}"), y=exp["avg_review"], name="Review", yaxis="y2",
                    mode="markers+lines", marker=dict(size=9, color="#0F172A"), line=dict(dash="dot", color="#0F172A"))
    fig.update_layout(title="% giao trễ và review theo cụm", yaxis=dict(ticksuffix="%"),
                      yaxis2=dict(overlaying="y", side="right", range=[1, 5], showgrid=False))
    ui.tile(fig)
with c3:
    fig = go.Figure(go.Bar(x=new["month"], y=new["new_customers"], marker_color=ui.GOOD))
    fig.update_layout(title="Khách hàng mới theo tháng")
    ui.tile(fig)
with c4:
    fig = go.Figure()
    fig.add_bar(x=rep["orders_bucket"], y=rep["pct_customers"], name="% khách", marker_color=ui.MUTED)
    fig.add_bar(x=rep["orders_bucket"], y=rep["pct_gmv"], name="% GMV", marker_color=ui.PRIMARY)
    fig.update_layout(title="Khách theo số đơn", barmode="group", xaxis=dict(title="Số đơn"),
                      yaxis=dict(ticksuffix="%"))
    ui.tile(fig)

ui.register(profile, "mkt_cluster_profile", "Hồ sơ cụm (dim_customer_cluster)")
ui.register(seg, "mkt_cluster_filtered", "Cụm theo bộ lọc")
ui.register(hist, "mkt_recency_hist", "Phân phối recency")
ui.register(geo, "mkt_cluster_state", "Cụm × bang")
ui.register(exp, "mkt_cluster_experience", "Giao trễ & review theo cụm")
ui.register(new, "mkt_new_customers", "Khách mới theo tháng")
ui.register(rep, "mkt_orders_per_customer", "Khách theo số đơn")
ui.footer([f"{MART}.dim_customer_cluster", f"{MART}.mart_customer_rfm", f"{MART}.mart_customer_360",
           "Cohort (GD4.5) & churn (GD4.8): chưa có trong kho"])
