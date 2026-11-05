"""Giao diện dùng chung: header (logo + bộ lọc), thẻ KPI, ô biểu đồ dạng lưới, menu tải dữ liệu.

Nguyên tắc trình bày: mỗi trang vừa 1 màn hình ngang 16:9, không viết sẵn nhận định.
Dashboard là cầu nối để nhà quản trị / DA tự đọc số và rút ra insight.
"""

import pandas as pd
import plotly.graph_objects as go
import plotly.io as pio
import streamlit as st

import db

# ---------------------------------------------------------------------------
# Bảng màu
# ---------------------------------------------------------------------------
PRIMARY = "#2563EB"
ACCENT = "#F59E0B"
GOOD = "#16A34A"
BAD = "#DC2626"
MUTED = "#94A3B8"
SEQ = ["#DBEAFE", "#93C5FD", "#3B82F6", "#1D4ED8", "#1E3A8A"]
# Màu cụm cố định, khớp hình trong notebook K-Means (C1 cam, C2 xanh lá, C3 đỏ, C4 xanh dương)
CLUSTER_COLORS = {1: "#F97316", 2: "#16A34A", 3: "#DC2626", 4: "#2563EB",
                  5: "#9333EA", 6: "#0891B2", 7: "#CA8A04", 8: "#DB2777", -1: "#94A3B8"}

pio.templates["olist"] = go.layout.Template(
    layout=dict(
        font=dict(family="Inter, Segoe UI, Arial, sans-serif", size=11, color="#334155"),
        colorway=[PRIMARY, ACCENT, GOOD, BAD, "#9333EA", "#0891B2", "#CA8A04", "#DB2777"],
        paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
        xaxis=dict(showgrid=False, linecolor="#CBD5E1", ticks="outside", tickcolor="#CBD5E1", title_font_size=11),
        yaxis=dict(gridcolor="#EEF2F7", zeroline=False, title_font_size=11),
        legend=dict(orientation="h", yanchor="bottom", y=1.0, xanchor="left", x=0, title_text="", font_size=10,
                    bgcolor="rgba(0,0,0,0)"),
        margin=dict(l=4, r=4, t=50, b=4),
        hoverlabel=dict(font_size=12),
        title=dict(font=dict(size=13, color="#0F172A"), x=0.01, xanchor="left", y=0.98, yanchor="top",
                   yref="container"),
    )
)
pio.templates.default = "plotly_white+olist"

CSS = """
<style>
.block-container, [data-testid="stMainBlockContainer"] {padding: 3.6rem 1.4rem 0.4rem 1.4rem !important; max-width: 100% !important;}
[data-testid="stSidebar"], [data-testid="stSidebarCollapsedControl"] {display: none;}
div[data-testid="stVerticalBlock"] {gap: 0.5rem;}
div[data-testid="stHorizontalBlock"] {gap: 0.6rem;}
/* Thẻ KPI */
.kpi {background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 10px; padding: 7px 12px; height: 80px; margin-bottom: 6px;
      box-shadow: 0 1px 2px rgba(15,23,42,.04);}
.kpi .lbl {font-size: .72rem; color: #64748B; font-weight: 600; text-transform: uppercase; letter-spacing: .03em;
           white-space: nowrap; overflow: hidden; text-overflow: ellipsis;}
.kpi .val {font-size: 1.35rem; font-weight: 700; color: #0F172A; line-height: 1.5;}
.kpi .sub {font-size: .72rem; color: #64748B;}
.kpi .up {color: #16A34A; font-weight: 600;} .kpi .down {color: #DC2626; font-weight: 600;}
/* Header */
.brand {display: flex; align-items: center; gap: 10px; height: 56px;}
.brand .mark {width: 38px; height: 38px; border-radius: 10px; background: linear-gradient(135deg,#1E3A8A,#3B82F6);
              color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 1.1rem;}
.brand .t1 {font-weight: 800; font-size: 1.05rem; color: #0F172A; line-height: 1.1;}
.brand .t2 {font-size: .74rem; color: #64748B;}
/* Ô biểu đồ */
div[data-testid="stVerticalBlockBorderWrapper"] {border-radius: 10px !important; border-color: #E2E8F0 !important;
                                                  background: #FFFFFF;}
.foot {font-size: .68rem; color: #94A3B8; text-align: right; margin-top: -4px;}
.stApp {background: #F5F7FB;}
</style>
"""

# ---------------------------------------------------------------------------
# Định dạng số
# ---------------------------------------------------------------------------
def brl(v: float, decimals: int = 2) -> str:
    if v is None or pd.isna(v):
        return "–"
    if abs(v) >= 1e6:
        return f"R$ {v / 1e6:,.{decimals}f}M"
    if abs(v) >= 1e3:
        return f"R$ {v / 1e3:,.1f}K"
    return f"R$ {v:,.2f}"


def num(v: float, decimals: int = 0) -> str:
    return "–" if v is None or pd.isna(v) else f"{v:,.{decimals}f}"


def pct(v: float, decimals: int = 1) -> str:
    return "–" if v is None or pd.isna(v) else f"{v:,.{decimals}f}%"


def ym_label(ym: int) -> str:
    return f"{ym // 100}-{ym % 100:02d}"


# ---------------------------------------------------------------------------
# Header: logo + tiêu đề trang + bộ lọc (giữ giá trị khi chuyển trang)
# ---------------------------------------------------------------------------
DEFAULT_RANGE = (201701, 201808)  # giai đoạn dữ liệu đầy đủ theo EDA (mục 2.2.4)


def _keep(key):
    if key in st.session_state:
        st.session_state[key] = st.session_state[key]


def _reset(lo, hi):
    st.session_state["f_months"] = (lo, hi)
    st.session_state["f_states"] = []
    st.session_state["f_clusters"] = []
    st.session_state["f_cats"] = []


def header(page_title: str, extra=None) -> dict:
    """Vẽ header và trả về bộ lọc. `extra(col)` vẽ thêm bộ lọc riêng của trang (vd. cụm khách hàng)."""
    st.markdown(CSS, unsafe_allow_html=True)
    months = db.available_months()
    labels = [ym_label(m) for m in months]
    lo = ym_label(DEFAULT_RANGE[0]) if DEFAULT_RANGE[0] in months else labels[0]
    hi = ym_label(DEFAULT_RANGE[1]) if DEFAULT_RANGE[1] in months else labels[-1]
    for k in ("f_months", "f_states", "f_clusters", "f_cats"):
        _keep(k)
    if "f_months" not in st.session_state or st.session_state["f_months"][0] not in labels:
        st.session_state["f_months"] = (lo, hi)

    widths = [2.2, 2.6, 2.2] + ([1.8] if extra else []) + [0.55, 0.75]
    cols = st.columns(widths, vertical_alignment="center")
    cols[0].markdown(f'<div class="brand"><div class="mark">O</div><div><div class="t1">Olist CRM · {page_title}</div>'
                     f'<div class="t2">Team 7 · Kho dữ liệu trên MotherDuck</div></div></div>',
                     unsafe_allow_html=True)
    rng = cols[1].select_slider("Tháng đặt mua", options=labels, key="f_months")
    states = cols[2].multiselect("Bang giao hàng", db.available_states(), key="f_states", placeholder="Tất cả 27 bang")
    i = 3
    extra_val = None
    if extra:
        extra_val = extra(cols[i])
        i += 1
    cols[i].button("↺", help="Đặt lại bộ lọc", on_click=_reset, args=(lo, hi), width="stretch")
    st.session_state["_dl_box"] = cols[i + 1].popover("⬇ Dữ liệu", width="stretch")
    st.session_state["_dl_items"] = []

    y1, m1 = map(int, rng[0].split("-"))
    y2, m2 = map(int, rng[1].split("-"))
    return {"date_from": y1 * 10000 + m1 * 100 + 1, "date_to": y2 * 10000 + m2 * 100 + 31,
            "label": f"{rng[0]} → {rng[1]}", "states": states, "extra": extra_val}


def register(df: pd.DataFrame, name: str, label: str):
    """Đưa bảng số liệu của 1 biểu đồ vào menu '⬇ Dữ liệu' trên header (CSV đúng con số đang hiển thị)."""
    box = st.session_state.get("_dl_box")
    if box is None:
        return
    with box:
        st.download_button(f"{label} ({len(df):,} dòng)", df.to_csv(index=False).encode("utf-8-sig"),
                           file_name=f"{name}.csv", mime="text/csv", key=f"dl_{name}", width="stretch")


def footer(sources: list[str]):
    st.markdown('<div class="foot">Nguồn: ' + " · ".join(sources) +
                " &nbsp;|&nbsp; Chỉ đơn delivered · Số đơn = COUNT(DISTINCT order_id) · GMV = price + freight · "
                "AOV = GMV ÷ số đơn · Trục thời gian = tháng đặt mua</div>", unsafe_allow_html=True)


# ---------------------------------------------------------------------------
# Thẻ KPI và ô biểu đồ
# ---------------------------------------------------------------------------
def kpis(items: list[tuple]):
    """items: (nhãn, giá trị, dòng phụ | None, delta_% | None)."""
    cols = st.columns(len(items))
    for col, it in zip(cols, items):
        label, value, sub, delta = (list(it) + [None, None])[:4]
        d = ""
        if delta is not None and not pd.isna(delta):
            cls = "up" if delta >= 0 else "down"
            d = f'<span class="{cls}">{"▲" if delta >= 0 else "▼"} {abs(delta):.1f}%</span> '
        col.markdown(f'<div class="kpi"><div class="lbl" title="{label}">{label}</div><div class="val">{value}</div>'
                     f'<div class="sub">{d}{sub or ""}</div></div>', unsafe_allow_html=True)


def tile(fig, height: int = 278):
    """Một ô biểu đồ có viền, chiều cao cố định để cả trang vừa 1 màn hình."""
    fig.update_layout(height=height)
    with st.container(border=True):
        st.plotly_chart(fig, width="stretch", config={"displaylogo": False, "displayModeBar": "hover",
                                                       "modeBarButtonsToRemove": ["lasso2d", "select2d"]})
