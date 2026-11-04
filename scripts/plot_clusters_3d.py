"""
Vẽ các cụm K-Means trên không gian 3 chiều Recency × Frequency × Monetary.

Đọc kết quả đã có trên MotherDuck (không chạy lại K-Means):
    main_mart.mart_customer_rfm   (recency_days, frequency, monetary, cluster_id)
    main_mart.dim_customer_cluster (cluster_label)

Đầu ra:
    docs/figures/ml/07_cluster_3d.png   ảnh tĩnh để chèn báo cáo
    docs/figures/ml/07_cluster_3d.html  biểu đồ tương tác (xoay, phóng to, rê chuột xem từng khách)

Chạy ở thư mục gốc repo:
    python scripts/plot_clusters_3d.py
"""

import os
import sys
from pathlib import Path

import duckdb
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parent.parent
FIG_DIR = ROOT / "docs" / "figures" / "ml"
FIG_DIR.mkdir(parents=True, exist_ok=True)

SAMPLE_PER_CLUSTER = 2000     # mỗi cụm lấy tối đa 2,000 khách để hình không bị dày đặc
RANDOM_STATE = 42
F_CAP = 5                     # frequency > 5 vẽ ở mức 5 (chỉ vài khách)
JITTER = 0.18                 # nhiễu nhỏ trên trục frequency để các điểm 1, 2, 3 đơn không chồng khít

# Màu cố định theo cluster_id, khớp với hình 05_cluster_scatter.png
COLORS = {1: "#ff7f0e", 2: "#2ca02c", 3: "#d62728", 4: "#1f77b4"}
FALLBACK = ["#9467bd", "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"]


def connect():
    load_dotenv(ROOT / ".env")
    test_db = os.getenv("ML_TEST_DUCKDB")
    if test_db:
        return duckdb.connect(test_db, read_only=True)
    token = os.getenv("MOTHERDUCK_TOKEN")
    if not token:
        sys.exit("Không tìm thấy MOTHERDUCK_TOKEN trong .env")
    db = os.getenv("MOTHERDUCK_DATABASE", "olist_warehouse")
    return duckdb.connect(f"md:{db}", config={"motherduck_token": token})


def main():
    con = connect()
    df = con.execute("""
        SELECT r.customer_unique_id, r.recency_days, r.frequency, CAST(r.monetary AS DOUBLE) AS monetary,
               r.cluster_id, d.cluster_label
        FROM main_mart.mart_customer_rfm r
        JOIN main_mart.dim_customer_cluster d USING (cluster_id)
        WHERE r.cluster_id <> -1
    """).df()
    con.close()
    if df.empty:
        sys.exit("mart_customer_rfm chưa có cluster_id. Chạy notebook K-Means và dbt build trước.")

    sizes = df.groupby("cluster_id").size()
    sample = pd.concat(
        [g.sample(min(len(g), SAMPLE_PER_CLUSTER), random_state=RANDOM_STATE) for _, g in df.groupby("cluster_id")],
        ignore_index=True,
    )
    rng = np.random.default_rng(RANDOM_STATE)
    sample = sample.assign(
        f_plot=sample["frequency"].clip(upper=F_CAP) + rng.uniform(-JITTER, JITTER, len(sample)),
        log_m=np.log10(sample["monetary"]),
    )
    cluster_ids = sorted(sample["cluster_id"].unique())
    color_of = {cid: COLORS.get(cid, FALLBACK[i % len(FALLBACK)]) for i, cid in enumerate(cluster_ids)}
    label_of = sample.drop_duplicates("cluster_id").set_index("cluster_id")["cluster_label"].to_dict()
    total = len(df)

    # ---------- Ảnh tĩnh (matplotlib) ----------
    fig = plt.figure(figsize=(11, 8.5))
    ax = fig.add_subplot(111, projection="3d")
    for cid in cluster_ids:
        g = sample[sample["cluster_id"] == cid]
        pct = 100 * sizes[cid] / total
        ax.scatter(g["recency_days"], g["f_plot"], g["log_m"], s=7, alpha=0.55, color=color_of[cid],
                   label=f"{label_of[cid]} — {sizes[cid]:,} khách ({pct:.1f}%)", depthshade=False)
    ticks_m = [10, 30, 100, 300, 1000, 3000, 10000]
    ax.set_zticks(np.log10(ticks_m))
    ax.set_zticklabels([f"{t:,}" for t in ticks_m])
    ax.set_yticks(range(1, F_CAP + 1))
    ax.set_yticklabels([str(i) for i in range(1, F_CAP)] + [f"≥{F_CAP}"])
    ax.set_xlabel("Recency (ngày từ lần mua cuối)", labelpad=10)
    ax.set_ylabel("Frequency (số đơn)", labelpad=8)
    ax.set_zlabel("Monetary (BRL, thang log)", labelpad=10)
    ax.view_init(elev=18, azim=-58)
    ax.set_title(f"Các cụm K-Means trên Recency × Frequency × Monetary\n"
                 f"(mẫu tối đa {SAMPLE_PER_CLUSTER:,} khách mỗi cụm; trục Frequency có thêm nhiễu nhỏ để dễ nhìn)",
                 fontsize=11)
    ax.legend(loc="upper left", fontsize=8.5, markerscale=2.5, frameon=True)
    plt.tight_layout()
    png = FIG_DIR / "07_cluster_3d.png"
    fig.savefig(png, dpi=150)
    plt.close(fig)
    print("Đã lưu", png)

    # ---------- Biểu đồ tương tác (plotly) ----------
    try:
        import plotly.graph_objects as go
    except ImportError:
        print("Chưa có plotly nên bỏ qua bản HTML. Cài bằng: python -m pip install plotly")
        return
    traces = []
    for cid in cluster_ids:
        g = sample[sample["cluster_id"] == cid]
        pct = 100 * sizes[cid] / total
        traces.append(go.Scatter3d(
            x=g["recency_days"], y=g["f_plot"], z=g["monetary"], mode="markers",
            name=f"{label_of[cid]} ({sizes[cid]:,} khách · {pct:.1f}%)",
            marker=dict(size=2.6, color=color_of[cid], opacity=0.7),
            customdata=np.stack([g["frequency"], g["monetary"]], axis=1),
            hovertemplate=("Recency: %{x} ngày<br>Frequency: %{customdata[0]} đơn"
                           "<br>Monetary: %{customdata[1]:,.2f} BRL<extra>" + label_of[cid] + "</extra>"),
        ))
    layout = go.Layout(
        title=dict(text="Các cụm K-Means trên Recency × Frequency × Monetary "
                        f"(mẫu tối đa {SAMPLE_PER_CLUSTER:,} khách mỗi cụm)", x=0.5),
        scene=dict(
            xaxis=dict(title="Recency (ngày)"),
            yaxis=dict(title="Frequency (số đơn)", tickvals=list(range(1, F_CAP + 1)),
                       ticktext=[str(i) for i in range(1, F_CAP)] + [f"≥{F_CAP}"]),
            zaxis=dict(title="Monetary (BRL, log)", type="log"),
            camera=dict(eye=dict(x=1.6, y=-1.6, z=0.8)),
        ),
        legend=dict(itemsizing="constant", x=0.01, y=0.98),
        margin=dict(l=0, r=0, t=50, b=0),
    )
    html = FIG_DIR / "07_cluster_3d.html"
    go.Figure(traces, layout).write_html(html, include_plotlyjs=True)
    print("Đã lưu", html)


if __name__ == "__main__":
    main()
