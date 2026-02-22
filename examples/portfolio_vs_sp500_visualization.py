#!/usr/bin/env python3
"""
Portfolio vs S&P 500 Benchmark Visualization
=============================================

Generates a multi-panel visualization comparing portfolio performance
against the S&P 500 benchmark, including:

  1. Cumulative returns over time
  2. Monthly return comparison (bar chart)
  3. Sector attribution (contribution to active return)
  4. Rolling risk metrics (volatility & tracking error)
  5. Summary statistics table

Usage:
    python portfolio_vs_sp500_visualization.py

Output:
    portfolio_vs_sp500.png

To integrate with the FactSet PA Engine SDK, replace the sample data
section with an API call (see the commented example at the bottom).
"""

import datetime as dt

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# 1.  Sample data – replace with live PA Engine results for production use
# ---------------------------------------------------------------------------

np.random.seed(42)

# 24 months of monthly dates
dates = pd.date_range("2024-01-31", periods=24, freq="ME")

# Simulate monthly returns (%)
sp500_monthly = np.random.normal(0.9, 3.8, size=len(dates))  # benchmark
# Portfolio has slight alpha with moderate tracking error
portfolio_monthly = sp500_monthly + np.random.normal(0.15, 1.4, size=len(dates))

returns_df = pd.DataFrame(
    {
        "Date": dates,
        "Portfolio": portfolio_monthly,
        "S&P 500": sp500_monthly,
    }
)
returns_df["Active"] = returns_df["Portfolio"] - returns_df["S&P 500"]

# Cumulative returns (growth of $100)
returns_df["Portfolio_Cumul"] = 100 * (1 + returns_df["Portfolio"] / 100).cumprod()
returns_df["SP500_Cumul"] = 100 * (1 + returns_df["S&P 500"] / 100).cumprod()

# Sector attribution data (contribution to active return, in bps)
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
# Allocation effect + selection effect = total attribution per sector
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

# Rolling 6-month annualised volatility
window = 6
port_vol = returns_df["Portfolio"].rolling(window).std() * np.sqrt(12)
sp500_vol = returns_df["S&P 500"].rolling(window).std() * np.sqrt(12)
tracking_err = returns_df["Active"].rolling(window).std() * np.sqrt(12)

# Summary statistics
stats = {
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
}

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

stats["Portfolio"] = [
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
]

stats["S&P 500"] = [
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
]

stats_df = pd.DataFrame(stats)

# ---------------------------------------------------------------------------
# 2.  Create the visualisation
# ---------------------------------------------------------------------------

NAVY = "#1B2A4A"
GOLD = "#C5A572"
BLUE = "#3A7CA5"
RED = "#D64045"
GREEN = "#2A9D8F"
GREY = "#888888"
BG = "#F7F7F9"

fig = plt.figure(figsize=(20, 24), facecolor=BG)
fig.suptitle(
    "Portfolio vs S&P 500  —  Performance Attribution Report",
    fontsize=22,
    fontweight="bold",
    color=NAVY,
    y=0.98,
)
fig.text(
    0.5,
    0.965,
    f"Period: {dates[0]:%b %Y} – {dates[-1]:%b %Y}  |  Generated {dt.date.today():%Y-%m-%d}",
    ha="center",
    fontsize=12,
    color=GREY,
)

gs = fig.add_gridspec(
    5, 2, hspace=0.38, wspace=0.28, left=0.07, right=0.95, top=0.94, bottom=0.03
)

# --- Panel 1: Cumulative Growth of $100 ------------------------------------
ax1 = fig.add_subplot(gs[0, :])
ax1.set_facecolor("white")
ax1.plot(
    returns_df["Date"],
    returns_df["Portfolio_Cumul"],
    color=BLUE,
    linewidth=2.5,
    label="Portfolio",
)
ax1.plot(
    returns_df["Date"],
    returns_df["SP500_Cumul"],
    color=GOLD,
    linewidth=2.5,
    label="S&P 500",
)
ax1.fill_between(
    returns_df["Date"],
    returns_df["Portfolio_Cumul"],
    returns_df["SP500_Cumul"],
    alpha=0.12,
    color=BLUE,
)
ax1.axhline(100, color=GREY, linewidth=0.6, linestyle="--")
ax1.set_title("Cumulative Growth of $100", fontsize=14, fontweight="bold", color=NAVY)
ax1.set_ylabel("Value ($)", fontsize=11)
ax1.legend(loc="upper left", fontsize=11)
ax1.yaxis.set_major_formatter(mticker.FormatStrFormatter("$%.0f"))
ax1.grid(axis="y", alpha=0.3)

# --- Panel 2: Monthly Returns Comparison -----------------------------------
ax2 = fig.add_subplot(gs[1, :])
ax2.set_facecolor("white")
x = np.arange(len(returns_df))
width = 0.35
ax2.bar(x - width / 2, returns_df["Portfolio"], width, label="Portfolio", color=BLUE, alpha=0.85)
ax2.bar(x + width / 2, returns_df["S&P 500"], width, label="S&P 500", color=GOLD, alpha=0.85)
ax2.axhline(0, color="black", linewidth=0.5)
ax2.set_xticks(x)
ax2.set_xticklabels(
    [d.strftime("%b\n%y") for d in returns_df["Date"]], fontsize=8
)
ax2.set_title("Monthly Returns Comparison (%)", fontsize=14, fontweight="bold", color=NAVY)
ax2.set_ylabel("Return (%)", fontsize=11)
ax2.legend(fontsize=10)
ax2.grid(axis="y", alpha=0.3)

# --- Panel 3: Sector Attribution (horizontal stacked bar) -------------------
ax3 = fig.add_subplot(gs[2, 0])
ax3.set_facecolor("white")
y_pos = np.arange(len(sector_df))
ax3.barh(
    y_pos,
    sector_df["Allocation"],
    height=0.4,
    label="Allocation Effect",
    color=BLUE,
    alpha=0.85,
)
ax3.barh(
    y_pos,
    sector_df["Selection"],
    height=0.4,
    left=sector_df["Allocation"],
    label="Selection Effect",
    color=GREEN,
    alpha=0.85,
)
ax3.set_yticks(y_pos)
ax3.set_yticklabels(sector_df["Sector"], fontsize=9)
ax3.axvline(0, color="black", linewidth=0.5)
ax3.set_xlabel("Attribution (bps)", fontsize=10)
ax3.set_title("Sector Attribution Decomposition", fontsize=13, fontweight="bold", color=NAVY)
ax3.legend(loc="lower right", fontsize=9)
ax3.grid(axis="x", alpha=0.3)

# --- Panel 4: Total Sector Attribution (sorted bar) -------------------------
ax4 = fig.add_subplot(gs[2, 1])
ax4.set_facecolor("white")
colors = [GREEN if v >= 0 else RED for v in sector_df["Total"]]
ax4.barh(y_pos, sector_df["Total"], color=colors, height=0.55, alpha=0.85)
ax4.set_yticks(y_pos)
ax4.set_yticklabels(sector_df["Sector"], fontsize=9)
ax4.axvline(0, color="black", linewidth=0.5)
ax4.set_xlabel("Total Attribution (bps)", fontsize=10)
ax4.set_title("Net Sector Contribution to Active Return", fontsize=13, fontweight="bold", color=NAVY)
ax4.grid(axis="x", alpha=0.3)
for i, v in enumerate(sector_df["Total"]):
    ax4.text(
        v + (1.2 if v >= 0 else -1.2),
        i,
        f"{v:+d}",
        va="center",
        ha="left" if v >= 0 else "right",
        fontsize=8,
        fontweight="bold",
    )

# --- Panel 5: Rolling Volatility & Tracking Error --------------------------
ax5 = fig.add_subplot(gs[3, :])
ax5.set_facecolor("white")
ax5.plot(
    returns_df["Date"], port_vol, color=BLUE, linewidth=2, label="Portfolio Vol (ann.)"
)
ax5.plot(
    returns_df["Date"], sp500_vol, color=GOLD, linewidth=2, label="S&P 500 Vol (ann.)"
)
ax5.plot(
    returns_df["Date"],
    tracking_err,
    color=RED,
    linewidth=2,
    linestyle="--",
    label="Tracking Error (ann.)",
)
ax5.set_title(
    f"Rolling {window}-Month Annualised Volatility & Tracking Error",
    fontsize=14,
    fontweight="bold",
    color=NAVY,
)
ax5.set_ylabel("Volatility (%)", fontsize=11)
ax5.yaxis.set_major_formatter(mticker.FormatStrFormatter("%.1f%%"))
ax5.legend(fontsize=10)
ax5.grid(axis="y", alpha=0.3)

# --- Panel 6: Summary Statistics Table --------------------------------------
ax6 = fig.add_subplot(gs[4, :])
ax6.set_facecolor("white")
ax6.axis("off")
ax6.set_title(
    "Summary Statistics", fontsize=14, fontweight="bold", color=NAVY, pad=12
)

table = ax6.table(
    cellText=stats_df.values,
    colLabels=stats_df.columns,
    cellLoc="center",
    loc="center",
)
table.auto_set_font_size(False)
table.set_fontsize(10)
table.scale(1, 1.6)

# Style header row
for j in range(len(stats_df.columns)):
    cell = table[0, j]
    cell.set_facecolor(NAVY)
    cell.set_text_props(color="white", fontweight="bold")

# Alternate row shading
for i in range(1, len(stats_df) + 1):
    for j in range(len(stats_df.columns)):
        cell = table[i, j]
        if i % 2 == 0:
            cell.set_facecolor("#EDF2F7")
        else:
            cell.set_facecolor("white")

# ---------------------------------------------------------------------------
# 3.  Save output
# ---------------------------------------------------------------------------
output_path = "portfolio_vs_sp500.png"
fig.savefig(output_path, dpi=150, bbox_inches="tight", facecolor=BG)
plt.close(fig)
print(f"Saved visualisation to {output_path}")


# ---------------------------------------------------------------------------
# Appendix: Using the FactSet PA Engine SDK (commented reference)
# ---------------------------------------------------------------------------
#
# To pull live portfolio attribution data from FactSet, install the SDK:
#
#   pip install fds.sdk.utils fds.protobuf.stach.extensions fds.sdk.PAEngine
#
# Then replace the sample data section above with something like:
#
#   from fds.sdk.utils.authentication import ConfidentialClient
#   import fds.sdk.PAEngine
#   from fds.sdk.PAEngine.api import pa_calculations_api, components_api
#   from fds.sdk.PAEngine.models import (
#       PACalculationParametersRoot,
#       PACalculationParameters,
#       PAIdentifier,
#       PADateParameters,
#   )
#
#   configuration = fds.sdk.PAEngine.Configuration(
#       fds_oauth_client=ConfidentialClient("/path/to/app-config.json")
#   )
#
#   with fds.sdk.PAEngine.ApiClient(configuration) as api_client:
#       calc_api = pa_calculations_api.PACalculationsApi(api_client)
#
#       pa_params = PACalculationParameters(
#           componentid="<your-component-id>",
#           accounts=[PAIdentifier(id="CLIENT:/PA3/MY_PORTFOLIO.ACCT")],
#           benchmarks=[PAIdentifier(id="BENCH:SP50")],
#           dates=PADateParameters(
#               startdate="20240101",
#               enddate="20251231",
#               frequency="Monthly",
#           ),
#       )
#
#       response = calc_api.post_and_calculate(
#           pa_calculation_parameters_root=PACalculationParametersRoot(
#               data={"1": pa_params}
#           )
#       )
#       # Poll for results, then parse STACH response into a DataFrame
#       # See the PA Engine SDK README for full polling + parsing examples.
