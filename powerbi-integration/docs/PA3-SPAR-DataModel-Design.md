# PA3 & SPAR Optimal Data Model Design for Power BI

## Overview

This document provides the optimal data model design and best practices for integrating FactSet's Portfolio Analytics (PA3) and Style, Performance, and Risk Analysis (SPAR) APIs with Power BI.

---

## Table of Contents

1. [Data Model Architecture](#data-model-architecture)
2. [Star Schema Design](#star-schema-design)
3. [Dimension Tables](#dimension-tables)
4. [Fact Tables](#fact-tables)
5. [Relationships](#relationships)
6. [Power Query Best Practices](#power-query-best-practices)
7. [Native Connector Architecture](#native-connector-architecture)
8. [DAX Measures](#dax-measures)
9. [Refresh Strategies](#refresh-strategies)
10. [Performance Optimization](#performance-optimization)

---

## Data Model Architecture

### Recommended Approach: Star Schema

For PA3 and SPAR data, a **star schema** is optimal because:

- Financial analytics data is inherently dimensional (time, accounts, securities, groups)
- Supports efficient aggregations and drill-downs
- Aligns with Power BI's VertiPaq engine optimization
- Enables reusable dimension tables across PA3 and SPAR fact tables

```
                    ┌─────────────────┐
                    │   Dim_Date      │
                    └────────┬────────┘
                             │
┌─────────────────┐    ┌─────┴─────┐    ┌─────────────────┐
│  Dim_Account    │────│  Fact_PA3 │────│  Dim_Security   │
└─────────────────┘    └─────┬─────┘    └─────────────────┘
                             │
                    ┌────────┴────────┐
                    │   Dim_Group     │
                    └─────────────────┘

                    ┌─────────────────┐
                    │   Dim_Date      │
                    └────────┬────────┘
                             │
┌─────────────────┐    ┌─────┴─────┐    ┌─────────────────┐
│  Dim_Account    │────│ Fact_SPAR │────│  Dim_Benchmark  │
└─────────────────┘    └─────┬─────┘    └─────────────────┘
                             │
                    ┌────────┴────────┐
                    │ Dim_ReturnType  │
                    └─────────────────┘
```

---

## Star Schema Design

### Design Principles

1. **Shared Dimensions**: Use common dimension tables (Date, Account, Currency) across PA3 and SPAR
2. **Conformed Keys**: Establish consistent surrogate keys for cross-analysis
3. **Granularity**: Design fact tables at the lowest useful grain (security-level for PA3, return-period for SPAR)
4. **Slowly Changing Dimensions**: Account for historical changes in groupings and classifications

---

## Dimension Tables

### Dim_Date (Shared)

```
Dim_Date
├── DateKey (INT) - PK, YYYYMMDD format
├── Date (DATE)
├── Year (INT)
├── Quarter (INT)
├── Month (INT)
├── MonthName (VARCHAR)
├── Week (INT)
├── DayOfWeek (INT)
├── DayName (VARCHAR)
├── IsWeekend (BIT)
├── IsMonthEnd (BIT)
├── IsQuarterEnd (BIT)
├── IsYearEnd (BIT)
├── FiscalYear (INT)
├── FiscalQuarter (INT)
└── FrequencyFlag (VARCHAR) - Daily/Weekly/Monthly/Quarterly/Annually
```

**Power Query (M) Generation:**
```m
let
    StartDate = #date(2010, 1, 1),
    EndDate = Date.From(DateTime.LocalNow()),
    NumberOfDays = Duration.Days(EndDate - StartDate) + 1,
    DateList = List.Dates(StartDate, NumberOfDays, #duration(1, 0, 0, 0)),
    DateTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    AddDateKey = Table.AddColumn(DateTable, "DateKey", each Number.From(Date.ToText([Date], "yyyyMMdd")), Int64.Type),
    AddYear = Table.AddColumn(AddDateKey, "Year", each Date.Year([Date]), Int64.Type),
    AddQuarter = Table.AddColumn(AddYear, "Quarter", each Date.QuarterOfYear([Date]), Int64.Type),
    AddMonth = Table.AddColumn(AddQuarter, "Month", each Date.Month([Date]), Int64.Type),
    AddMonthName = Table.AddColumn(AddMonth, "MonthName", each Date.MonthName([Date])),
    AddIsMonthEnd = Table.AddColumn(AddMonthName, "IsMonthEnd", each Date.IsInCurrentMonth([Date]) and [Date] = Date.EndOfMonth([Date]), type logical)
in
    AddIsMonthEnd
```

---

### Dim_Account (Shared)

```
Dim_Account
├── AccountKey (INT) - PK, Surrogate key
├── AccountId (VARCHAR) - Natural key from FactSet (e.g., "Client:Portfolio.ACCT")
├── AccountName (VARCHAR)
├── AccountPath (VARCHAR) - Full path in FactSet
├── AccountType (VARCHAR) - ACCT, ACTM
├── HoldingsMode (VARCHAR) - B&H, TBR, OMS, EXT, VLT (PA3 specific)
├── BaseCurrency (VARCHAR)
├── InceptionDate (DATE)
├── IsActive (BIT)
└── LastUpdated (DATETIME)
```

**Best Practice**: Load accounts dynamically from the API:
```
GET /analytics/lookups/v3/accounts/{path}
```

---

### Dim_Benchmark (Shared)

```
Dim_Benchmark
├── BenchmarkKey (INT) - PK
├── BenchmarkId (VARCHAR) - Natural key (e.g., "BENCH:SP500")
├── BenchmarkName (VARCHAR)
├── BenchmarkType (VARCHAR) - Index, Composite, Custom
├── ReturnType (VARCHAR) - GR (Gross), NET (Net)
├── Prefix (VARCHAR) - Identifier prefix
├── BaseCurrency (VARCHAR)
└── IsActive (BIT)
```

---

### Dim_Security (PA3)

```
Dim_Security
├── SecurityKey (INT) - PK
├── SecurityId (VARCHAR) - FactSet identifier
├── SecurityName (VARCHAR)
├── Ticker (VARCHAR)
├── CUSIP (VARCHAR)
├── ISIN (VARCHAR)
├── SEDOL (VARCHAR)
├── SecurityType (VARCHAR)
├── Sector (VARCHAR)
├── Industry (VARCHAR)
├── Country (VARCHAR)
├── Currency (VARCHAR)
├── MarketCap (DECIMAL)
└── IsActive (BIT)
```

---

### Dim_Group (PA3)

```
Dim_Group
├── GroupKey (INT) - PK
├── GroupId (VARCHAR) - FactSet group ID
├── GroupName (VARCHAR)
├── GroupCategory (VARCHAR) - Sector, Industry, Region, etc.
├── GroupLevel (INT) - Hierarchy level
├── ParentGroupKey (INT) - FK to self for hierarchy
└── SortOrder (INT)
```

---

### Dim_Column (PA3)

```
Dim_Column
├── ColumnKey (INT) - PK
├── ColumnId (VARCHAR) - FactSet column ID (hash)
├── ColumnName (VARCHAR)
├── ColumnCategory (VARCHAR)
├── ColumnDirectory (VARCHAR)
├── DataType (VARCHAR)
└── IsCalculated (BIT)
```

---

### Dim_Component (Shared)

```
Dim_Component
├── ComponentKey (INT) - PK
├── ComponentId (VARCHAR) - FactSet component ID
├── ComponentName (VARCHAR)
├── ComponentPath (VARCHAR)
├── ComponentCategory (VARCHAR)
├── EngineType (VARCHAR) - PA3, SPAR
├── IsSnapshot (BIT)
└── DefaultFrequency (VARCHAR)
```

---

### Dim_Currency (Shared)

```
Dim_Currency
├── CurrencyKey (INT) - PK
├── CurrencyCode (VARCHAR) - ISO code
├── CurrencyName (VARCHAR)
└── Symbol (VARCHAR)
```

---

### Dim_ReturnType (SPAR)

```
Dim_ReturnType
├── ReturnTypeKey (INT) - PK
├── ReturnTypeId (VARCHAR) - GR, NET, etc.
├── ReturnTypeName (VARCHAR) - Gross Returns, Net Returns
└── Description (VARCHAR)
```

---

### Dim_Frequency (Shared)

```
Dim_Frequency
├── FrequencyKey (INT) - PK
├── FrequencyCode (VARCHAR) - D, W, M, Q, A
├── FrequencyName (VARCHAR) - Daily, Weekly, Monthly, Quarterly, Annually
├── DaysInPeriod (INT) - Approximate days
└── PeriodsPerYear (INT)
```

---

## Fact Tables

### Fact_PA3_Performance

Primary fact table for PA3 performance attribution data.

```
Fact_PA3_Performance
├── PerformanceKey (BIGINT) - PK
├── DateKey (INT) - FK to Dim_Date
├── AccountKey (INT) - FK to Dim_Account
├── BenchmarkKey (INT) - FK to Dim_Benchmark
├── SecurityKey (INT) - FK to Dim_Security (nullable for group-level)
├── GroupKey (INT) - FK to Dim_Group
├── ComponentKey (INT) - FK to Dim_Component
├── CurrencyKey (INT) - FK to Dim_Currency
├── FrequencyKey (INT) - FK to Dim_Frequency
├── CalculationId (VARCHAR) - FactSet calculation ID for traceability
│
│ -- Measures (example columns, varies by PA3 component)
├── PortfolioReturn (DECIMAL)
├── BenchmarkReturn (DECIMAL)
├── ActiveReturn (DECIMAL)
├── AllocationEffect (DECIMAL)
├── SelectionEffect (DECIMAL)
├── InteractionEffect (DECIMAL)
├── TotalEffect (DECIMAL)
├── PortfolioWeight (DECIMAL)
├── BenchmarkWeight (DECIMAL)
├── ActiveWeight (DECIMAL)
├── PortfolioContribution (DECIMAL)
├── BenchmarkContribution (DECIMAL)
└── ActiveContribution (DECIMAL)
```

**Grain**: One row per Date × Account × Benchmark × Security/Group × Component

---

### Fact_PA3_Holdings

Holdings-based fact table for position-level analysis.

```
Fact_PA3_Holdings
├── HoldingKey (BIGINT) - PK
├── DateKey (INT) - FK
├── AccountKey (INT) - FK
├── SecurityKey (INT) - FK
├── CurrencyKey (INT) - FK
│
├── Quantity (DECIMAL)
├── MarketValue (DECIMAL)
├── MarketValueLocal (DECIMAL)
├── CostBasis (DECIMAL)
├── UnrealizedGainLoss (DECIMAL)
├── Weight (DECIMAL)
├── Price (DECIMAL)
└── PriceLocal (DECIMAL)
```

---

### Fact_PA3_Risk

Risk metrics fact table.

```
Fact_PA3_Risk
├── RiskKey (BIGINT) - PK
├── DateKey (INT) - FK
├── AccountKey (INT) - FK
├── BenchmarkKey (INT) - FK
├── SecurityKey (INT) - FK (nullable)
├── GroupKey (INT) - FK
├── FrequencyKey (INT) - FK
│
├── Volatility (DECIMAL)
├── TrackingError (DECIMAL)
├── Beta (DECIMAL)
├── Alpha (DECIMAL)
├── SharpeRatio (DECIMAL)
├── InformationRatio (DECIMAL)
├── MaxDrawdown (DECIMAL)
├── VaR_95 (DECIMAL)
├── VaR_99 (DECIMAL)
├── CVaR_95 (DECIMAL)
└── CVaR_99 (DECIMAL)
```

---

### Fact_SPAR_Analysis

Primary fact table for SPAR analysis results.

```
Fact_SPAR_Analysis
├── SPARKey (BIGINT) - PK
├── DateKey (INT) - FK to Dim_Date
├── AccountKey (INT) - FK to Dim_Account
├── BenchmarkKey (INT) - FK to Dim_Benchmark
├── ComponentKey (INT) - FK to Dim_Component
├── ReturnTypeKey (INT) - FK to Dim_ReturnType
├── CurrencyKey (INT) - FK to Dim_Currency
├── FrequencyKey (INT) - FK to Dim_Frequency
├── CalculationId (VARCHAR)
│
│ -- Performance Measures
├── PortfolioReturn (DECIMAL)
├── BenchmarkReturn (DECIMAL)
├── ExcessReturn (DECIMAL)
├── CumulativeReturn (DECIMAL)
├── AnnualizedReturn (DECIMAL)
│
│ -- Risk Measures
├── StandardDeviation (DECIMAL)
├── TrackingError (DECIMAL)
├── Beta (DECIMAL)
├── RSquared (DECIMAL)
├── Alpha (DECIMAL)
│
│ -- Risk-Adjusted Measures
├── SharpeRatio (DECIMAL)
├── TreynorRatio (DECIMAL)
├── InformationRatio (DECIMAL)
├── SortinoRatio (DECIMAL)
│
│ -- Style Analysis
├── StyleExposure_Value (DECIMAL)
├── StyleExposure_Growth (DECIMAL)
├── StyleExposure_Size (DECIMAL)
├── StyleExposure_Momentum (DECIMAL)
└── StyleExposure_Quality (DECIMAL)
```

**Grain**: One row per Date × Account × Benchmark × Component × ReturnType

---

### Fact_SPAR_TimeSeries

Time-series returns for trend analysis.

```
Fact_SPAR_TimeSeries
├── TimeSeriesKey (BIGINT) - PK
├── DateKey (INT) - FK
├── AccountKey (INT) - FK
├── BenchmarkKey (INT) - FK
├── ReturnTypeKey (INT) - FK
├── FrequencyKey (INT) - FK
│
├── PeriodReturn (DECIMAL)
├── CumulativeReturn (DECIMAL)
├── RollingReturn_1Y (DECIMAL)
├── RollingReturn_3Y (DECIMAL)
├── RollingReturn_5Y (DECIMAL)
├── RollingVolatility_1Y (DECIMAL)
└── RollingVolatility_3Y (DECIMAL)
```

---

## Relationships

### Relationship Diagram

```
┌──────────────┐     ┌──────────────────────┐     ┌───────────────┐
│  Dim_Date    │────<│  Fact_PA3_Performance│>────│ Dim_Account   │
└──────────────┘     └──────────────────────┘     └───────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
       ┌──────┴─────┐  ┌──────┴─────┐  ┌──────┴─────┐
       │Dim_Security│  │ Dim_Group  │  │Dim_Benchmark│
       └────────────┘  └────────────┘  └────────────┘

┌──────────────┐     ┌──────────────────────┐     ┌───────────────┐
│  Dim_Date    │────<│   Fact_SPAR_Analysis │>────│ Dim_Account   │
└──────────────┘     └──────────────────────┘     └───────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
       ┌──────┴─────┐  ┌──────┴─────┐  ┌──────┴─────┐
       │Dim_Benchmark│ │Dim_ReturnType│ │Dim_Component│
       └────────────┘  └────────────┘  └────────────┘
```

### Relationship Definitions

| From Table | From Column | To Table | To Column | Cardinality | Cross-Filter |
|------------|-------------|----------|-----------|-------------|--------------|
| Fact_PA3_Performance | DateKey | Dim_Date | DateKey | Many-to-One | Single |
| Fact_PA3_Performance | AccountKey | Dim_Account | AccountKey | Many-to-One | Single |
| Fact_PA3_Performance | BenchmarkKey | Dim_Benchmark | BenchmarkKey | Many-to-One | Single |
| Fact_PA3_Performance | SecurityKey | Dim_Security | SecurityKey | Many-to-One | Single |
| Fact_PA3_Performance | GroupKey | Dim_Group | GroupKey | Many-to-One | Single |
| Fact_PA3_Performance | ComponentKey | Dim_Component | ComponentKey | Many-to-One | Single |
| Fact_PA3_Performance | CurrencyKey | Dim_Currency | CurrencyKey | Many-to-One | Single |
| Fact_SPAR_Analysis | DateKey | Dim_Date | DateKey | Many-to-One | Single |
| Fact_SPAR_Analysis | AccountKey | Dim_Account | AccountKey | Many-to-One | Single |
| Fact_SPAR_Analysis | BenchmarkKey | Dim_Benchmark | BenchmarkKey | Many-to-One | Single |
| Fact_SPAR_Analysis | ComponentKey | Dim_Component | ComponentKey | Many-to-One | Single |
| Fact_SPAR_Analysis | ReturnTypeKey | Dim_ReturnType | ReturnTypeKey | Many-to-One | Single |

### Best Practices for Relationships

1. **Use Surrogate Keys**: Integer surrogate keys improve join performance
2. **Single Direction Cross-Filter**: Avoid bidirectional filtering unless necessary
3. **Avoid Circular Dependencies**: Keep relationships in a clean star/snowflake pattern
4. **Handle Missing Keys**: Use `-1` or `0` for "Unknown" dimension members

---

## Summary

This data model provides:

- **Unified view** of PA3 and SPAR analytics through shared dimensions
- **Flexible analysis** at multiple granularities (security, group, portfolio level)
- **Optimal performance** through star schema design
- **Scalability** for large datasets with proper partitioning strategies
- **Auditability** through calculation ID tracking

Continue to the companion documents for:
- [Power Query Best Practices](./PowerQuery-BestPractices.md)
- [Native Connector Architecture](./NativeConnector-Architecture.md)
