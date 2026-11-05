"""Sales · Ngành hàng & người bán — fact_sales × dim_product × dim_seller, review trọng số 1/k."""

import plotly.graph_objects as go
import streamlit as st

import db
import ui
from db import GOLD

# Tên ngành tiếng Anh; nếu chưa dịch được thì dùng tên tiếng Bồ Đào Nha để không gộp hết vào 'unknown'
CAT = ("COALESCE(NULLIF(p.product_category_name_english, 'unknown'), "
       "NULLIF(p.product_category_name_portuguese, 'unknown'), 'unknown')")
all_cats = db.query(f"SELECT DISTINCT {CAT} AS c FROM {GOLD}.dim_product p ORDER BY 1")["c"].tolist()


def cat_filter(col):
    return col.multiselect("Ngành hàng", all_cats, key="f_cats", placeholder="Tất cả ngành")


f = ui.header("Sales · Ngành hàng", extra=cat_filter)
where, params = db.sales_where(f)
if f["extra"]:
    where += f" AND list_contains(?, {CAT})"
    params += (tuple(f["extra"]),)
J = f"FROM {GOLD}.fact_sales f LEFT JOIN {GOLD}.dim_product p USING (product_id)"

cats = db.query(f"""
    SELECT {CAT} AS category, SUM(f.gmv) AS gmv, SUM(f.price) AS revenue, COUNT(DISTINCT f.order_id) AS orders,
           SUM(f.quantity) AS items, SUM(f.gmv) / COUNT(DISTINCT f.order_id) AS aov,
           100 * SUM(f.freight_value) / SUM(f.gmv) AS freight_pct, COUNT(DISTINCT f.seller_id) AS sellers
    {J} WHERE {where} GROUP BY 1 ORDER BY 2 DESC
""", params)
cats["share"] = 100 * cats["gmv"] / cats["gmv"].sum()
csat = db.query(f"""
    WITH items AS (SELECT f.order_id, {CAT} AS category {J} WHERE {where}),
         k AS (SELECT order_id, COUNT(*) AS k FROM items GROUP BY 1)
    SELECT i.category, SUM(r.review_score / k.k) / SUM(1.0 / k.k) AS avg_review,
           100 * COALESCE(SUM(CASE WHEN r.review_score <= 2 THEN 1.0 / k.k END), 0) / SUM(1.0 / k.k) AS low_pct,
           SUM(1.0 / k.k) AS weighted_reviews
    FROM items i JOIN k USING (order_id) JOIN {GOLD}.fact_customer_reviews r USING (order_id)
    GROUP BY 1
""", params)
sellers = db.query(f"""
    WITH s AS (SELECT f.seller_id, SUM(f.gmv) AS gmv {J} WHERE {where} GROUP BY 1)
    SELECT 100.0 * ROW_NUMBER() OVER (ORDER BY gmv DESC) / COUNT(*) OVER () AS seller_pct,
           100.0 * SUM(gmv) OVER (ORDER BY gmv DESC ROWS UNBOUNDED PRECEDING) / SUM(gmv) OVER () AS gmv_pct
    FROM s ORDER BY 1
""", params)

tot = csat["weighted_reviews"].sum()
ui.kpis([
    ("Ngành có doanh số", ui.num(len(cats)), None),
    ("Top 10 ngành chiếm", ui.pct(cats.head(10)["share"].sum()), "% GMV"),
    ("Seller hoạt động", ui.num(len(sellers)), None),
    ("20% seller đầu chiếm", ui.pct(sellers.loc[sellers["seller_pct"] <= 20, "gmv_pct"].max()), "% GMV"),
    ("Item / đơn", ui.num(cats["items"].sum() / max(cats["orders"].sum(), 1), 2), None),
    ("Review TB (1/k)", ui.num((csat["avg_review"] * csat["weighted_reviews"]).sum() / tot if tot else None, 2), None),
    ("Review 1–2 sao", ui.pct((csat["low_pct"] * csat["weighted_reviews"]).sum() / tot if tot else None), None),
])

# --- Hàng 1 --------------------------------------------------------------------------------------
pick = f["extra"] or cats.head(5)["category"].tolist()
tr = db.query(f"""
    SELECT (f.purchase_date_key // 100) AS ym, {CAT} AS category, SUM(f.gmv) AS gmv
    {J} WHERE {where} AND list_contains(?, {CAT}) GROUP BY 1, 2 ORDER BY 1
""", params + (tuple(pick),))
tr["month"] = tr["ym"].astype(int).map(ui.ym_label)

c1, c2, c3 = st.columns([1.05, 1.35, 1])
with c1:
    top = cats.head(12).iloc[::-1]
    fig = go.Figure(go.Bar(x=top["gmv"], y=top["category"], orientation="h", marker_color=ui.PRIMARY,
                           text=top["share"].map(lambda v: f"{v:.1f}%"), textposition="outside", cliponaxis=False))
    fig.update_layout(title="Top 12 ngành theo GMV", yaxis=dict(tickfont_size=9),
                      xaxis=dict(visible=False, range=[0, top["gmv"].max() * 1.22]))
    ui.tile(fig)
with c2:
    fig = go.Figure()
    for c, g in tr.groupby("category"):
        fig.add_scatter(x=g["month"], y=g["gmv"], name=c, mode="lines", line=dict(width=2))
    fig.update_layout(title="GMV theo tháng · " + ("ngành đã chọn" if f["extra"] else "top 5 ngành"),
                      legend=dict(font_size=9))
    ui.tile(fig)
with c3:
    t = cats.head(25)
    fig = go.Figure(go.Scatter(x=t["orders"], y=t["aov"], mode="markers", text=t["category"],
                               hovertemplate="%{text}<br>Đơn %{x:,}<br>AOV %{y:,.0f}<extra></extra>",
                               marker=dict(size=8 + 22 * t["gmv"] / t["gmv"].max(), color=t["freight_pct"],
                                           colorscale="Oranges", showscale=True,
                                           colorbar=dict(title="% cước", thickness=8))))
    fig.update_layout(title="Số đơn × AOV (25 ngành lớn)", xaxis=dict(title="Số đơn", type="log"),
                      yaxis=dict(title="AOV (BRL)"))
    ui.tile(fig)

# --- Hàng 2 --------------------------------------------------------------------------------------
ss = db.query(f"""
    SELECT s.seller_state, COUNT(DISTINCT f.seller_id) AS sellers, SUM(f.gmv) AS gmv
    {J} JOIN {GOLD}.dim_seller s USING (seller_id) WHERE {where} GROUP BY 1 ORDER BY 3 DESC
""", params)
ss["share"] = 100 * ss["gmv"] / ss["gmv"].sum()

c1, c2, c3 = st.columns([1.15, 1, 1])
with c1:
    worst = csat[csat["weighted_reviews"] >= 100].sort_values("low_pct", ascending=False).head(12).iloc[::-1]
    fig = go.Figure(go.Bar(x=worst["low_pct"], y=worst["category"], orientation="h", marker_color=ui.BAD,
                           text=worst["avg_review"].map(lambda v: f"★{v:.2f}"), textposition="outside",
                           cliponaxis=False))
    fig.update_layout(title="% review 1–2 sao cao nhất (≥ 100 review)", yaxis=dict(tickfont_size=9),
                      xaxis=dict(ticksuffix="%", range=[0, (worst["low_pct"].max() if len(worst) else 1) * 1.3]))
    ui.tile(fig)
with c2:
    fig = go.Figure(go.Scatter(x=sellers["seller_pct"], y=sellers["gmv_pct"], mode="lines", fill="tozeroy",
                               line=dict(color=ui.PRIMARY, width=2)))
    fig.add_scatter(x=[0, 100], y=[0, 100], mode="lines", line=dict(dash="dot", color=ui.MUTED))
    fig.update_layout(title="Pareto seller: % seller → % GMV", showlegend=False,
                      xaxis=dict(ticksuffix="%"), yaxis=dict(ticksuffix="%"))
    ui.tile(fig)
with c3:
    t = ss.head(10).iloc[::-1]
    fig = go.Figure(go.Bar(x=t["share"], y=t["seller_state"], orientation="h", marker_color=ui.ACCENT,
                           text=t["sellers"].map(lambda v: f"{v:,} seller"), textposition="outside", cliponaxis=False))
    fig.update_layout(title="% GMV theo bang người bán",
                      xaxis=dict(ticksuffix="%", range=[0, (t["share"].max() if len(t) else 1) * 1.35]))
    ui.tile(fig)

top_sellers = db.query(f"""
    SELECT f.seller_id, s.seller_state, s.seller_city, SUM(f.gmv) AS gmv, COUNT(DISTINCT f.order_id) AS orders
    {J} JOIN {GOLD}.dim_seller s USING (seller_id) WHERE {where} GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 100
""", params)
ui.register(cats, "sales_categories", "Ngành hàng")
ui.register(tr, "sales_category_trend", "Xu hướng ngành")
ui.register(csat.sort_values("low_pct", ascending=False), "sales_category_csat", "Review theo ngành (1/k)")
ui.register(ss, "sales_seller_state", "GMV theo bang seller")
ui.register(top_sellers, "sales_top100_sellers", "Top 100 seller")
ui.footer([f"{GOLD}.fact_sales", f"{GOLD}.dim_product", f"{GOLD}.dim_seller", f"{GOLD}.fact_customer_reviews"])
