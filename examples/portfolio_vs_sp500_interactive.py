#!/usr/bin/env python3
"""
Portfolio vs S&P 500 — Interactive Plotly Dashboard
====================================================

Generates an interactive HTML dashboard comparing portfolio performance
against the S&P 500 benchmark, including:

  1. Cumulative returns over time (with hover details)
  2. Monthly return comparison (grouped bar chart)
  3. Sector attribution decomposition (stacked horizontal bar)
  4. Net sector contribution to active return
  5. Rolling volatility & tracking error
  6. Summary statistics table

Usage:
    python portfolio_vs_sp500_interactive.py

Output:
    portfolio_vs_sp500_interactive.html

To integrate with the FactSet PA Engine SDK, replace the sample data
section with an API call (see the commented appendix in
portfolio_vs_sp500_visualization.py).
"""

import datetime as dt

import numpy as np
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots

# ---------------------------------------------------------------------------
# 1.  Sample data – replace with live PA Engine results for production use
# ---------------------------------------------------------------------------

np.random.seed(42)

dates = pd.date_range("2024-01-31", periods=24, freq="ME")

sp500_monthly = np.random.normal(0.9, 3.8, size=len(dates))
portfolio_monthly = sp500_monthly + np.random.normal(0.15, 1.4, size=len(dates))

returns_df = pd.DataFrame(
    {
        "Date": dates,
        "Portfolio": portfolio_monthly,
        "S&P 500": sp500_monthly,
    }
)
returns_df["Active"] = returns_df["Portfolio"] - returns_df["S&P 500"]

returns_df["Portfolio_Cumul"] = 100 * (1 + returns_df["Portfolio"] / 100).cumprod()
returns_df["SP500_Cumul"] = 100 * (1 + returns_df["S&P 500"] / 100).cumprod()

sectors = [
    "Information Technology",
    "Health Care",
    "Financials",
    "Consumer Discretionary",
    "Industrials",
    "Communication Services",
    "Energy",
    "Consumer Staples",
    "Materials",
    "Real Estate",
    "Utilities",
]
allocation_effect = [18, 12, -5, 8, 3, -2, -10, 4, 6, -3, 1]
selection_effect = [25, -8, 14, 3, 7, 10, -6, -3, 2, 5, -4]
total_attribution = [a + s for a, s in zip(allocation_effect, selection_effect)]

sector_df = pd.DataFrame(
    {
        "Sector": sectors,
        "Allocation": allocation_effect,
        "Selection": selection_effect,
        "Total": total_attribution,
    }
).sort_values("Total", ascending=True)

window = 6
returns_df["Port_Vol"] = returns_df["Portfolio"].rolling(window).std() * np.sqrt(12)
returns_df["SP500_Vol"] = returns_df["S&P 500"].rolling(window).std() * np.sqrt(12)
returns_df["Tracking_Err"] = returns_df["Active"].rolling(window).std() * np.sqrt(12)


def _cum(col):
    return (1 + returns_df[col] / 100).prod() - 1


def _ann(col):
    n = len(returns_df)
    return (1 + _cum(col)) ** (12 / n) - 1


def _vol(col):
    return returns_df[col].std() * np.sqrt(12) / 100


def _sharpe(col, rf=0.045):
    return (_ann(col) - rf) / _vol(col) if _vol(col) else float("nan")


def _maxdd(col):
    cum = (1 + returns_df[col] / 100).cumprod()
    peak = cum.cummax()
    dd = (cum - peak) / peak
    return dd.min()


pct = lambda v: f"{v:+.2%}" if v >= 0 else f"{v:.2%}"

stats_data = {
    "Metric": [
        "Cumulative Return",
        "Annualised Return",
        "Annualised Volatility",
        "Sharpe Ratio (Rf=4.5%)",
        "Max Drawdown",
        "Best Month",
        "Worst Month",
        "% Positive Months",
        "Information Ratio",
        "Tracking Error (ann.)",
    ],
    "Portfolio": [
        pct(_cum("Portfolio")),
        pct(_ann("Portfolio")),
        f"{_vol('Portfolio'):.2%}",
        f"{_sharpe('Portfolio'):.2f}",
        f"{_maxdd('Portfolio'):.2%}",
        f"{returns_df['Portfolio'].max():.2f}%",
        f"{returns_df['Portfolio'].min():.2f}%",
        f"{(returns_df['Portfolio'] > 0).mean():.0%}",
        f"{(_ann('Portfolio') - _ann('S&P 500')) / (returns_df['Active'].std() * np.sqrt(12) / 100):.2f}",
        f"{returns_df['Active'].std() * np.sqrt(12) / 100:.2%}",
    ],
    "S&P 500": [
        pct(_cum("S&P 500")),
        pct(_ann("S&P 500")),
        f"{_vol('S&P 500'):.2%}",
        f"{_sharpe('S&P 500'):.2f}",
        f"{_maxdd('S&P 500'):.2%}",
        f"{returns_df['S&P 500'].max():.2f}%",
        f"{returns_df['S&P 500'].min():.2f}%",
        f"{(returns_df['S&P 500'] > 0).mean():.0%}",
        "—",
        "—",
    ],
}
stats_df = pd.DataFrame(stats_data)

# ---------------------------------------------------------------------------
# 2.  Colour palette
# ---------------------------------------------------------------------------

NAVY = "#1B2A4A"
GOLD = "#C5A572"
BLUE = "#3A7CA5"
RED = "#D64045"
GREEN = "#2A9D8F"
GREY = "#888888"

# ---------------------------------------------------------------------------
# 3.  Build Plotly dashboard
# ---------------------------------------------------------------------------

fig = make_subplots(
    rows=5,
    cols=2,
    row_heights=[0.22, 0.22, 0.22, 0.22, 0.12],
    column_widths=[0.5, 0.5],
    specs=[
        [{"colspan": 2}, None],
        [{"colspan": 2}, None],
        [{"type": "xy"}, {"type": "xy"}],
        [{"colspan": 2}, None],
        [{"type": "table", "colspan": 2}, None],
    ],
    subplot_titles=[
        "Cumulative Growth of $100",
        "Monthly Returns Comparison (%)",
        "Sector Attribution Decomposition",
        "Net Sector Contribution to Active Return",
        f"Rolling {window}-Month Annualised Volatility & Tracking Error",
        "Summary Statistics",
    ],
    vertical_spacing=0.06,
    horizontal_spacing=0.08,
)

# --- Panel 1: Cumulative Growth of $100 ------------------------------------

fig.add_trace(
    go.Scatter(
        x=returns_df["Date"],
        y=returns_df["Portfolio_Cumul"],
        name="Portfolio",
        line=dict(color=BLUE, width=2.5),
        hovertemplate="<b>Portfolio</b><br>%{x|%b %Y}<br>$%{y:.2f}<extra></extra>",
    ),
    row=1,
    col=1,
)
fig.add_trace(
    go.Scatter(
        x=returns_df["Date"],
        y=returns_df["SP500_Cumul"],
        name="S&P 500",
        line=dict(color=GOLD, width=2.5),
        hovertemplate="<b>S&P 500</b><br>%{x|%b %Y}<br>$%{y:.2f}<extra></extra>",
    ),
    row=1,
    col=1,
)
# Shaded area between the two lines
fig.add_trace(
    go.Scatter(
        x=returns_df["Date"],
        y=returns_df["Portfolio_Cumul"],
        line=dict(width=0),
        showlegend=False,
        hoverinfo="skip",
    ),
    row=1,
    col=1,
)
fig.add_trace(
    go.Scatter(
        x=returns_df["Date"],
        y=returns_df["SP500_Cumul"],
        line=dict(width=0),
        fill="tonexty",
        fillcolor="rgba(58,124,165,0.1)",
        showlegend=False,
        hoverinfo="skip",
    ),
    row=1,
    col=1,
)
fig.add_hline(y=100, line_dash="dash", line_color=GREY, line_width=0.8, row=1, col=1)
fig.update_yaxes(tickprefix="$", row=1, col=1)

# --- Panel 2: Monthly Returns Comparison -----------------------------------

date_labels = [d.strftime("%b %y") for d in returns_df["Date"]]

fig.add_trace(
    go.Bar(
        x=date_labels,
        y=returns_df["Portfolio"],
        name="Portfolio ",  # trailing space to avoid legend merge
        marker_color=BLUE,
        opacity=0.85,
        hovertemplate="<b>Portfolio</b><br>%{x}<br>%{y:.2f}%<extra></extra>",
        showlegend=False,
    ),
    row=2,
    col=1,
)
fig.add_trace(
    go.Bar(
        x=date_labels,
        y=returns_df["S&P 500"],
        name="S&P 500 ",
        marker_color=GOLD,
        opacity=0.85,
        hovertemplate="<b>S&P 500</b><br>%{x}<br>%{y:.2f}%<extra></extra>",
        showlegend=False,
    ),
    row=2,
    col=1,
)
fig.update_layout(barmode="group")
fig.update_yaxes(title_text="Return (%)", row=2, col=1)

# --- Panel 3: Sector Attribution Decomposition ------------------------------

fig.add_trace(
    go.Bar(
        y=sector_df["Sector"],
        x=sector_df["Allocation"],
        name="Allocation Effect",
        orientation="h",
        marker_color=BLUE,
        opacity=0.85,
        hovertemplate="<b>%{y}</b><br>Allocation: %{x:+d} bps<extra></extra>",
    ),
    row=3,
    col=1,
)
fig.add_trace(
    go.Bar(
        y=sector_df["Sector"],
        x=sector_df["Selection"],
        name="Selection Effect",
        orientation="h",
        marker_color=GREEN,
        opacity=0.85,
        hovertemplate="<b>%{y}</b><br>Selection: %{x:+d} bps<extra></extra>",
    ),
    row=3,
    col=1,
)
fig.update_xaxes(title_text="Attribution (bps)", row=3, col=1)

# --- Panel 4: Net Sector Contribution --------------------------------------

bar_colors = [GREEN if v >= 0 else RED for v in sector_df["Total"]]

fig.add_trace(
    go.Bar(
        y=sector_df["Sector"],
        x=sector_df["Total"],
        orientation="h",
        marker_color=bar_colors,
        opacity=0.85,
        text=[f"{v:+d}" for v in sector_df["Total"]],
        textposition="outside",
        textfont=dict(size=10, color=NAVY),
        hovertemplate="<b>%{y}</b><br>Total: %{x:+d} bps<extra></extra>",
        showlegend=False,
    ),
    row=3,
    col=2,
)
fig.update_xaxes(title_text="Total Attribution (bps)", row=3, col=2)

# Stack the sector attribution bars (panel 3) relative to each other
fig.update_layout(barmode="relative")

# --- Panel 5: Rolling Volatility & Tracking Error --------------------------

fig.add_trace(
    go.Scatter(
        x=returns_df["Date"],
        y=returns_df["Port_Vol"],
        name="Portfolio Vol (ann.)",
        line=dict(color=BLUE, width=2),
        hovertemplate="<b>Portfolio Vol</b><br>%{x|%b %Y}<br>%{y:.1f}%<extra></extra>",
    ),
    row=4,
    col=1,
)
fig.add_trace(
    go.Scatter(
        x=returns_df["Date"],
        y=returns_df["SP500_Vol"],
        name="S&P 500 Vol (ann.)",
        line=dict(color=GOLD, width=2),
        hovertemplate="<b>S&P 500 Vol</b><br>%{x|%b %Y}<br>%{y:.1f}%<extra></extra>",
    ),
    row=4,
    col=1,
)
fig.add_trace(
    go.Scatter(
        x=returns_df["Date"],
        y=returns_df["Tracking_Err"],
        name="Tracking Error (ann.)",
        line=dict(color=RED, width=2, dash="dash"),
        hovertemplate="<b>Tracking Error</b><br>%{x|%b %Y}<br>%{y:.1f}%<extra></extra>",
    ),
    row=4,
    col=1,
)
fig.update_yaxes(title_text="Volatility (%)", ticksuffix="%", row=4, col=1)

# --- Panel 6: Summary Statistics Table -------------------------------------

header_fill = NAVY
header_font = "white"
even_fill = "#EDF2F7"
odd_fill = "white"

row_colors = [odd_fill if i % 2 == 0 else even_fill for i in range(len(stats_df))]

fig.add_trace(
    go.Table(
        header=dict(
            values=[f"<b>{c}</b>" for c in stats_df.columns],
            fill_color=header_fill,
            font=dict(color=header_font, size=12),
            align="center",
            height=32,
        ),
        cells=dict(
            values=[stats_df[c] for c in stats_df.columns],
            fill_color=[row_colors],
            font=dict(size=11),
            align="center",
            height=28,
        ),
    ),
    row=5,
    col=1,
)

# ---------------------------------------------------------------------------
# 4.  Global layout
# ---------------------------------------------------------------------------

fig.update_layout(
    height=1600,
    width=1200,
    title=dict(
        text=(
            "<b>Portfolio vs S&P 500 — Performance Attribution Report</b>"
            f"<br><span style='font-size:13px;color:{GREY}'>"
            f"Period: {dates[0]:%b %Y} – {dates[-1]:%b %Y}  |  "
            f"Generated {dt.date.today():%Y-%m-%d}</span>"
        ),
        x=0.5,
        font=dict(size=20, color=NAVY),
    ),
    plot_bgcolor="white",
    paper_bgcolor="#F7F7F9",
    font=dict(family="Segoe UI, Helvetica, Arial, sans-serif"),
    legend=dict(
        orientation="h",
        yanchor="top",
        y=-0.02,
        xanchor="center",
        x=0.5,
        font=dict(size=11),
    ),
    hovermode="x unified",
    margin=dict(t=100, b=60, l=60, r=40),
)

# Style subplot titles
for ann in fig.layout.annotations:
    ann.font = dict(size=14, color=NAVY)

# ---------------------------------------------------------------------------
# 5.  Save output
# ---------------------------------------------------------------------------

output_path = "portfolio_vs_sp500_interactive.html"
fig.write_html(output_path, include_plotlyjs=True, full_html=True)
print(f"Saved interactive dashboard to {output_path}")
