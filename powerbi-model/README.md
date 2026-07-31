# FactSet Enterprise Analytics - Power BI Semantic Model

A production-ready Power BI semantic model (BIM) that connects to FactSet's REST APIs to deliver comprehensive financial analytics across pricing, fundamentals, estimates, ESG, ownership, and benchmark data.

## Architecture

```
powerbi-model/
  FactSetEnterpriseModel.bim   # Tabular model definition (import into Power BI / SSAS)
  queries/
    FactSetAPIHelper.pq        # Shared Power Query functions (pagination, retry, batching)
    FactSetFormulaAPI.pq       # Formula API integration for custom FQL queries
  README.md                    # This file
```

### Data Model (Star Schema)

```
                          DimDate
                            |
                            | (Date)
                            |
DimBenchmark --- FactBenchmarkConstituents
                            |
                            | (FsymId)
                            |
FactPrices ─────┐           |
FactReturns ────┤           |
FactDividends ──┤── DimSecurity ── DimEntity
FactFundamentals┤     (FsymId)     (EntityId)
FactEstimates ──┤
FactESGScores ──┤
FactOwnership ──┘
                            |
                            | (Currency)
                            |
                        DimCurrency
```

### Tables

| Table | Source API | Description |
|-------|-----------|-------------|
| **DimDate** | Generated | Calendar + fiscal date hierarchy (2010 - present) |
| **DimEntity** | Entity API v1 | Company profiles, HQ location, descriptions |
| **DimSecurity** | Entity API v1 | Security listings, tickers, exchanges |
| **DimCurrency** | Static | ISO currency reference |
| **DimBenchmark** | Benchmarks API v1 | Index reference data |
| **FactPrices** | Prices API v1 | Daily OHLCV price data |
| **FactReturns** | Prices API v1 | Monthly total returns |
| **FactDividends** | Prices API v1 | Dividend payments with ex/record/pay dates |
| **FactFundamentals** | Fundamentals API v2 | 25 financial metrics across income, balance sheet, cash flow |
| **FactEstimatesConsensus** | Estimates API v2 | Rolling consensus (mean, median, high, low, count) |
| **FactEstimatesSurprise** | Estimates API v2 | Actual vs. estimate with surprise amounts |
| **FactESGScores** | ESG API v3 | E, S, G pillar scores and composite rankings |
| **FactOwnership** | Ownership API v1 | Top 50 institutional holders per security |
| **FactBenchmarkConstituents** | Benchmarks API v1 | Index weights, sectors, countries |

### Measures (60+ DAX calculations)

Organized in display folders:

- **Price Metrics** - Latest close, period high/low, VWAP, avg volume
- **Return Metrics** - Daily return, cumulative return, annualized return, volatility, Sharpe ratio
- **Fundamental Metrics**
  - Income Statement: Revenue, net income, EBITDA, EPS
  - Per Share: BPS, DPS, EPS
  - Valuation: P/E, P/B, EV/EBITDA, dividend yield, FCF yield
  - Profitability: Gross/operating/net margin, ROE, ROA
  - Balance Sheet: Total assets, equity, D/E ratio
  - Cash Flow: Operating CF, CapEx, FCF
- **Growth Metrics** - Revenue YoY, EPS YoY
- **Estimates** - Consensus EPS/revenue (NTM), forward P/E, analyst count, estimate spread
- **Surprise** - EPS beat rate, avg surprise %, last surprise
- **ESG** - Composite score, E/S/G pillars, percentile rank
- **Ownership** - Institutional %, holder count, top-10 concentration
- **Dividends** - Total paid, annual dividend, dividend count
- **Benchmark** - Weight, active weight
- **Portfolio** - Security count, entity count

## Setup

### Prerequisites

1. **FactSet account** with API access enabled
2. **OAuth 2.0 application** registered at [developer.factset.com](https://developer.factset.com/applications)
3. **API entitlements** for the data sets you need (Prices, Fundamentals, Estimates, etc.)
4. **Power BI Desktop** (July 2024 or later recommended) or **Azure Analysis Services**

### Step 1: Import the Model

**Power BI Desktop:**
1. Open Power BI Desktop
2. File > Open report > Browse for `.bim` files (or import via Tabular Editor)
3. Alternatively, use [Tabular Editor](https://tabulareditor.com/) to open the `.bim` file and deploy to Power BI Service

**Tabular Editor (recommended):**
1. Open Tabular Editor 2 or 3
2. File > Open > Model from File > select `FactSetEnterpriseModel.bim`
3. Review and modify as needed
4. Deploy to Power BI Service or Azure Analysis Services

### Step 2: Configure Authentication

In the model's Power Query parameters (under `expressions` in the BIM file):

1. **`FactSet_AccessToken`** - Replace `YOUR_CLIENT_ID` and `YOUR_CLIENT_SECRET` with your FactSet OAuth 2.0 credentials
2. Alternatively, configure the data source credentials in Power BI Service after deployment

### Step 3: Customize Your Watchlist

Edit the **`FactSet_WatchlistIds`** parameter to include your securities of interest:

```m
// Use FactSet ticker-region format
ids = {"AAPL-US", "MSFT-US", "SHEL-GB", "7203-JP", "SAP-DE"}
```

### Step 4: Set Date Ranges

- **`FactSet_StartDate`** - Historical start date (default: `"2020-01-01"`)
- **`FactSet_EndDate`** - End date (default: `"0"` = today)
- **`FactSet_FiscalStart`** / **`FactSet_FiscalEnd`** - Fiscal period offsets for fundamentals

### Step 5: Refresh Data

After configuring credentials and parameters, refresh all tables. The model uses Import mode - schedule regular refreshes in Power BI Service for up-to-date data.

## Extending the Model

### Adding New Metrics to Fundamentals

Edit the `metricsToFetch` list in the `FactFundamentals` partition query:

```m
metricsToFetch = {"FF_SALES", "FF_NET_INC", "FF_YOUR_NEW_METRIC", ...}
```

See the [FactSet Fundamentals API metrics endpoint](https://developer.factset.com/api-catalog/factset-fundamentals-api) for available metrics.

### Using the Formula API

For data items not available through dedicated APIs, use the Formula API queries in `queries/FactSetFormulaAPI.pq`:

```m
let
    result = FactSetFormulaAPI[CrossSection](
        {"AAPL-US", "MSFT-US"},
        {"P_PRICE(0,,,,'USD')", "FF_SALES(ANN_R,0)"},
        FactSet_AccessToken
    )
in
    result
```

### Adding Custom DAX Measures

Add measures to the `_Measures` table in the BIM file. Use `displayFolder` to organize them:

```json
{
  "name": "My Custom Metric",
  "expression": "DIVIDE([Revenue (Latest)], [Market Cap], BLANK())",
  "formatString": "0.00%",
  "displayFolder": "Custom Metrics",
  "lineageTag": "m-custom-001"
}
```

## API Rate Limits

| API | Rate Limit |
|-----|-----------|
| Prices | 25 req/sec |
| Fundamentals | 10 req/sec |
| Estimates | 10 req/sec |
| Entity | 10 req/sec |
| ESG | 10 req/sec |
| Ownership | 10 req/sec |
| Benchmarks | 10 req/sec |

The `FactSetAPIHelper.pq` module includes retry logic with exponential backoff for rate-limited requests.

## Relationships

All fact tables connect to `DimSecurity` via `FsymId`. Only the `FactPrices -> DimSecurity` relationship is active by default (bidirectional) to avoid ambiguity. Other relationships are inactive and can be activated per-measure using `USERELATIONSHIP()`:

```dax
My Measure =
CALCULATE(
    SUM(FactFundamentals[Value]),
    USERELATIONSHIP(FactFundamentals[FsymId], DimSecurity[FsymId])
)
```

## License

This model is part of the [FactSet Enterprise SDK](https://github.com/factset/enterprise-sdk) and is licensed under the Apache License 2.0.
