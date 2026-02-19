# Column Abbreviation Reference

Quick reference for standardized column names used in Power BI attribution reports.

## Naming Convention

```
[Entity][Metric][Modifier]

Entity:    P = Portfolio, B = Benchmark, A = Active
Metric:    Rtn = Return, Wt = Weight, Ctr = Contribution, etc.
Modifier:  Bop = Beginning of Period, Eop = End of Period, Avg = Average
```

---

## Returns

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `PRtn` | Portfolio Return | Total portfolio return |
| `PRtnTot` | Portfolio Total Return | Total return including income |
| `PRtnPrc` | Portfolio Price Return | Price return only |
| `PRtnInc` | Portfolio Income Return | Income/dividend return |
| `PRtnLcl` | Portfolio Local Return | Return in local currency |
| `PRtnBase` | Portfolio Base Return | Return in base currency |
| `BRtn` | Benchmark Return | Total benchmark return |
| `BRtnTot` | Benchmark Total Return | Total return including income |
| `BRtnPrc` | Benchmark Price Return | Price return only |
| `BRtnInc` | Benchmark Income Return | Income/dividend return |
| `BRtnLcl` | Benchmark Local Return | Return in local currency |
| `BRtnBase` | Benchmark Base Return | Return in base currency |
| `ARtn` | Active Return | Portfolio minus benchmark (PRtn - BRtn) |
| `ExRtn` | Excess Return | Return above risk-free rate |
| `RelRtn` | Relative Return | Relative performance measure |

---

## Weights

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `PWt` | Portfolio Weight | Default/current portfolio weight |
| `PWtBop` | Portfolio Weight BOP | Weight at beginning of period |
| `PWtEop` | Portfolio Weight EOP | Weight at end of period |
| `PWtAvg` | Portfolio Weight Average | Time-weighted average weight |
| `BWt` | Benchmark Weight | Default/current benchmark weight |
| `BWtBop` | Benchmark Weight BOP | Weight at beginning of period |
| `BWtEop` | Benchmark Weight EOP | Weight at end of period |
| `BWtAvg` | Benchmark Weight Average | Time-weighted average weight |
| `AWt` | Active Weight | Default over/underweight (PWt - BWt) |
| `AWtBop` | Active Weight BOP | Over/underweight at period start |
| `AWtEop` | Active Weight EOP | Over/underweight at period end |
| `AWtAvg` | Active Weight Average | Average over/underweight |

---

## Attribution Effects

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `Alloc` | Allocation Effect | Effect from weight differences |
| `Sel` | Selection Effect | Effect from security selection |
| `Int` | Interaction Effect | Allocation × Selection interaction |
| `TotEff` | Total Effect | Sum of all attribution effects |
| `AllocBrin` | Allocation (Brinson) | Brinson methodology allocation |
| `SelBrin` | Selection (Brinson) | Brinson methodology selection |
| `AllocBF` | Allocation (Brinson-Fachler) | BF methodology allocation |
| `SelBF` | Selection (Brinson-Fachler) | BF methodology selection |
| `AllocBHB` | Allocation (Brinson-Hood-Beebower) | BHB methodology |
| `SelBHB` | Selection (BHB) | BHB methodology selection |
| `CcyEff` | Currency Effect | FX translation impact |
| `FxEff` | FX Effect | Foreign exchange effect |
| `HedgeEff` | Hedging Effect | Currency hedge impact |

---

## Contributions

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `PCtr` | Portfolio Contribution | Contribution to portfolio return |
| `BCtr` | Benchmark Contribution | Contribution to benchmark return |
| `ACtr` | Active Contribution | Contribution to active return |

---

## Market Values

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `PMV` | Portfolio Market Value | Current portfolio market value |
| `PMVBop` | Portfolio MV BOP | Market value at period start |
| `PMVEop` | Portfolio MV EOP | Market value at period end |
| `BMV` | Benchmark Market Value | Current benchmark market value |
| `BMVBop` | Benchmark MV BOP | Market value at period start |
| `BMVEop` | Benchmark MV EOP | Market value at period end |
| `MV` | Market Value | Generic market value |
| `MVLcl` | Market Value Local | Value in local currency |
| `MVBase` | Market Value Base | Value in base currency |

---

## Quantities & Prices

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `Qty` | Quantity | Number of shares/units |
| `PQty` | Portfolio Quantity | Portfolio position quantity |
| `BQty` | Benchmark Quantity | Benchmark position quantity |
| `Prc` | Price | Security price |
| `PrcLcl` | Price Local | Price in local currency |
| `PrcBase` | Price Base | Price in base currency |
| `PPrc` | Portfolio Price | Portfolio-level price |
| `BPrc` | Benchmark Price | Benchmark-level price |

---

## Risk Metrics

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `Vol` | Volatility | Standard deviation of returns |
| `StdDev` | Standard Deviation | Same as volatility |
| `PVol` | Portfolio Volatility | Portfolio standard deviation |
| `BVol` | Benchmark Volatility | Benchmark standard deviation |
| `TE` | Tracking Error | Active return volatility |
| `ActRisk` | Active Risk | Same as tracking error |
| `Beta` | Beta | Systematic risk measure |
| `Alpha` | Alpha | Risk-adjusted excess return |
| `Sharpe` | Sharpe Ratio | Return per unit of total risk |
| `IR` | Information Ratio | Active return per tracking error |
| `Sortino` | Sortino Ratio | Return per downside risk |
| `Treynor` | Treynor Ratio | Return per unit of beta |
| `MaxDD` | Maximum Drawdown | Largest peak-to-trough decline |
| `VaR95` | Value at Risk 95% | 95th percentile loss |
| `VaR99` | Value at Risk 99% | 99th percentile loss |
| `CVaR95` | Conditional VaR 95% | Expected shortfall at 95% |
| `CVaR99` | Conditional VaR 99% | Expected shortfall at 99% |
| `RSq` | R-Squared | Coefficient of determination |

---

## Identifiers

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `SecName` | Security Name | Full security name |
| `Ticker` | Ticker | Exchange ticker symbol |
| `CUSIP` | CUSIP | Committee on Uniform Securities ID |
| `ISIN` | ISIN | International Securities ID |
| `SEDOL` | SEDOL | Stock Exchange Daily Official List |
| `FSID` | FactSet ID | FactSet entity identifier |
| `EntityID` | Entity ID | FactSet entity ID |

---

## Groupings

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `Grp` | Group | Generic grouping |
| `GrpName` | Group Name | Grouping name/label |
| `Sector` | Sector | GICS sector |
| `Ind` | Industry | GICS industry |
| `IndGrp` | Industry Group | GICS industry group |
| `SubInd` | Sub-Industry | GICS sub-industry |
| `Ctry` | Country | Country of domicile |
| `Rgn` | Region | Geographic region |
| `AssetCls` | Asset Class | Asset class (Equity, FI, etc.) |
| `AssetTyp` | Asset Type | Detailed asset type |
| `Ccy` | Currency | Currency code |
| `MktCap` | Market Cap | Market capitalization band |
| `Style` | Style | Investment style (Value/Growth) |

---

## Dates

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `Date` | Date | Primary date field |
| `DateKey` | Date Key | Integer key (YYYYMMDD) |
| `Period` | Period | Analysis period |
| `PrdStart` | Period Start | Period start date |
| `PrdEnd` | Period End | Period end date |
| `StartDt` | Start Date | Generic start date |
| `EndDt` | End Date | Generic end date |
| `AsOfDt` | As Of Date | Valuation date |
| `TrdDt` | Trade Date | Transaction trade date |
| `SettleDt` | Settlement Date | Transaction settlement date |

---

## Other

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `HoldMode` | Holdings Mode | B&H, TBR, OMS, etc. |
| `TxnType` | Transaction Type | Buy, Sell, etc. |
| `BuySell` | Buy/Sell | Transaction direction |

---

## Derived Calculations

These are automatically calculated if source columns exist:

| Derived | Formula | Required Columns |
|---------|---------|------------------|
| `ARtn` | PRtn - BRtn | PRtn, BRtn |
| `AWt` | PWt - BWt | PWt, BWt |
| `AWtBop` | PWtBop - BWtBop | PWtBop, BWtBop |
| `AWtEop` | PWtEop - BWtEop | PWtEop, BWtEop |
| `AWtAvg` | PWtAvg - BWtAvg | PWtAvg, BWtAvg |
| `ACtr` | PCtr - BCtr | PCtr, BCtr |
| `TotEff` | Alloc + Sel + Int | Alloc, Sel, (Int optional) |

---

## Example Column Headers in Power BI

Before standardization:
```
Port. Weight BOP | Port. Weight EOP | Port. Weight Avg | Bench. Weight BOP | ...
```

After standardization:
```
PWtBop | PWtEop | PWtAvg | BWtBop | ...
```

Header width reduction: ~60%
