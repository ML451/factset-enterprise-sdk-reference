# Universal Screening API - Insights for Future Power BI Integration

## Overview

This document captures key insights about FactSet's Universal Screening API for future Power BI integration work. Universal Screening is a powerful tool for security selection that can serve as a foundation for downstream PA3/SPAR portfolio analysis.

---

## Table of Contents

1. [API Purpose](#api-purpose)
2. [Key Capabilities](#key-capabilities)
3. [Endpoints Reference](#endpoints-reference)
4. [Data Models](#data-models)
5. [Integration with PA3/SPAR](#integration-with-pa3spar)
6. [Power BI Data Model Extension](#power-bi-data-model-extension)
7. [Implementation Patterns](#implementation-patterns)

---

## API Purpose

The Universal Screening API provides programmatic access to FactSet's Universal Screening Application, enabling:

- Execute saved screening definitions against security universes
- Retrieve and analyze screening results in multiple formats
- Archive screening results to OFDB (FactSet Database)
- Export results to various file formats (PDF, Excel, CSV)
- Manage long-running screening jobs asynchronously

**API Version**: v2.0.2
**Base URL**: `https://api.factset.com/universal-screening/v2`
**Spec Location**: `/specs/UniversalScreening.v2.yaml`

---

## Key Capabilities

| Capability | Description |
|------------|-------------|
| **Screen Execution** | Run pre-configured screens by name/path |
| **Universe Support** | Equity, debt, and fund universes |
| **Parameterization** | Modify global variables and backtest dates at execution time |
| **Output Formats** | PDF, Excel, CSV, and legacy database exports |
| **OFDB Integration** | Archive symbol lists or time-series results |
| **Pagination** | Handle large result sets (100,000+ rows) |
| **Async Processing** | Long-running jobs with status polling |

---

## Endpoints Reference

### Screening Operations

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/job/calculate` | POST | Submit a screen calculation job |
| `/job/{id}` | GET | Retrieve paginated calculation results |
| `/job/{id}/status` | GET | Poll job execution status |
| `/job/export` | POST | Submit export job (PDF/Excel/CSV) |
| `/job/{id}/export` | GET | Retrieve exported file (binary) |

### Job Management

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/job/archive` | POST | Submit screen archive to OFDB |
| `/jobs` | GET | List all active jobs for user |
| `/jobs` | DELETE | Cancel all active jobs |
| `/job/{id}` | DELETE | Cancel specific job |

---

## Data Models

### ScreenCalcParameters (Request)

```json
{
  "data": {
    "screenName": "SAMPLE_SCREENS:KPI_AIR.USWEB",
    "backtestDate": "20240101",
    "globalVariablesMap": {
      "THRESHOLD": "50",
      "REGION": "US"
    },
    "legacyUniverseType": "equity"
  }
}
```

### ResourceStatusResponse

```json
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426655440000",
    "status": "queued|executing|created|failed|cancelled",
    "error": {
      "code": "parameterError",
      "title": "Invalid screen parameter",
      "id": "error-uuid"
    }
  }
}
```

### PaginatedCalculationResponse

```json
{
  "data": {
    "columns": [...],
    "rows": [...]
  },
  "meta": {
    "pagination": {
      "total": 2500,
      "isEstimatedTotal": false,
      "next": "cursor-for-next-page",
      "prev": null
    }
  }
}
```

**Result Format**: Stach v2 (column-oriented) - same format as PA3/SPAR results.

### Archive Options

```json
{
  "data": {
    "screenName": "SCREENS:MY_SCREEN.USWEB",
    "archiveOptions": {
      "archiveType": "ofdbSymbols|ofdb|ofdbNts|ofdbQuickNts",
      "filename": "personal:/my_screening_results.ofdb",
      "archiveDate": "20240101",
      "symbolType": "cusip|ticker|isin",
      "overwriteData": true,
      "autoSymbolUpdates": false
    }
  }
}
```

---

## Integration with PA3/SPAR

### Architecture: Screening-Driven Portfolio Analysis

```
┌─────────────────────────────────────────────────────────────────┐
│                    Universal Screening API                       │
│                                                                  │
│  Input: Screen definition + parameters + backtest date          │
│  Output: Filtered security list (symbols, metrics)              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              Security List (Dynamic Portfolio)                   │
│                                                                  │
│  - CUSIPs, Tickers, ISINs                                       │
│  - Screening metrics/scores                                      │
│  - Ranking information                                           │
└─────────────────────┬───────────────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          │                       │
          ▼                       ▼
┌─────────────────────┐   ┌─────────────────────┐
│      PA3 Engine     │   │    SPAR Engine      │
│                     │   │                     │
│ - Attribution       │   │ - Style Analysis    │
│ - Holdings Analysis │   │ - Risk Metrics      │
│ - Performance       │   │ - Benchmark Compare │
└─────────────────────┘   └─────────────────────┘
          │                       │
          └───────────┬───────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Power BI Data Model                          │
│                                                                  │
│  Dim_ScreenedSecurities ←──→ Fact_PA3_Performance               │
│  Dim_ScreeningExecution ←──→ Fact_SPAR_Analysis                 │
└─────────────────────────────────────────────────────────────────┘
```

### Use Cases

1. **Screened Portfolio Performance**
   - Screen for securities meeting criteria
   - Create dynamic portfolio from results
   - Run PA3 attribution on screened securities

2. **Risk Analysis of Screened Universe**
   - Screen for high-yield bonds meeting criteria
   - Run SPAR risk analysis on results
   - Compare to benchmark

3. **Time-Series Screening**
   - Run screen at multiple backtest dates
   - Track how screened universe changes over time
   - Correlate with PA3/SPAR performance

4. **What-If Analysis**
   - Vary screening parameters (thresholds, criteria)
   - Compare resulting portfolios
   - Analyze performance sensitivity

---

## Power BI Data Model Extension

### Additional Dimension Tables

#### Dim_ScreeningExecution

```
Dim_ScreeningExecution
├── ScreeningExecutionKey (INT) - PK
├── ScreenName (VARCHAR) - e.g., "SAMPLE_SCREENS:KPI_AIR.USWEB"
├── ScreenPath (VARCHAR)
├── BacktestDate (DATE)
├── ExecutionTimestamp (DATETIME)
├── GlobalVariables (VARCHAR) - JSON string
├── UniverseType (VARCHAR) - equity, debt, fund
├── ResultCount (INT)
├── Status (VARCHAR) - completed, failed
└── JobId (VARCHAR) - FactSet job UUID
```

#### Dim_ScreenCriteria

```
Dim_ScreenCriteria
├── CriteriaKey (INT) - PK
├── ScreeningExecutionKey (INT) - FK
├── ParameterName (VARCHAR) - A, B, C... (global variable)
├── ParameterValue (VARCHAR)
├── ParameterDescription (VARCHAR)
└── IsActive (BIT)
```

### Additional Fact Tables

#### Fact_ScreeningResults

```
Fact_ScreeningResults
├── ScreeningResultKey (BIGINT) - PK
├── ScreeningExecutionKey (INT) - FK to Dim_ScreeningExecution
├── SecurityKey (INT) - FK to Dim_Security (shared with PA3)
├── DateKey (INT) - FK to Dim_Date
│
│ -- Screening Output Metrics (dynamic based on screen)
├── ScreenRank (INT)
├── PassedFilter (BIT)
├── Metric1 (DECIMAL) - Screen-specific
├── Metric2 (DECIMAL)
├── Metric3 (DECIMAL)
├── ... (extend based on screen output)
└── MetricN (DECIMAL)
```

### Extended Relationships

```
Dim_ScreeningExecution
        │
        │ 1:N
        ▼
Fact_ScreeningResults ──────────────── Dim_Security
        │                                    │
        │                                    │
        │                              (Shared Key)
        │                                    │
        │                                    ▼
        │                           Fact_PA3_Performance
        │                           Fact_PA3_Holdings
        │                           Fact_SPAR_Analysis
        │
        └──→ Allows filtering PA3/SPAR results
             by screening criteria
```

---

## Implementation Patterns

### Power Query: Execute Screen and Get Results

```m
// Universal Screening - Execute and retrieve results
let
    ExecuteScreen = (
        screenName as text,
        optional backtestDate as text,
        optional globalVariables as record
    ) =>
    let
        // Build request
        RequestBody = [
            data = Record.Combine({
                [screenName = screenName],
                if backtestDate <> null then [backtestDate = backtestDate] else [],
                if globalVariables <> null then [globalVariablesMap = globalVariables] else []
            })
        ],

        // Submit calculation job
        SubmitResponse = CallFactSetAPI(
            "/universal-screening/v2/job/calculate",
            "POST",
            RequestBody
        ),

        JobId = SubmitResponse[data][id],

        // Poll for completion
        PollForResults = (jobId as text) =>
            let
                MaxAttempts = 120,
                PollInterval = 5,

                Poll = (attempt as number) =>
                    let
                        Status = CallFactSetAPI(
                            "/universal-screening/v2/job/" & jobId & "/status"
                        ),
                        CurrentStatus = Status[data][status]
                    in
                        if CurrentStatus = "created" then
                            // Results ready
                            GetPaginatedResults(jobId)
                        else if CurrentStatus = "failed" then
                            error Error.Record("Screening Failed", Status[data][error][title], Status)
                        else if attempt >= MaxAttempts then
                            error Error.Record("Timeout", "Screening exceeded maximum wait time", null)
                        else
                            let
                                _ = Function.InvokeAfter(() => null, #duration(0, 0, 0, PollInterval))
                            in
                                @Poll(attempt + 1)
            in
                Poll(1),

        Results = PollForResults(JobId)
    in
        Results,

    // Get paginated results
    GetPaginatedResults = (jobId as text) =>
        let
            GetPage = (cursor as text) =>
                let
                    Endpoint = "/universal-screening/v2/job/" & jobId &
                        "?_paginationLimit=100000" &
                        (if cursor <> "" then "&_paginationCursor=" & cursor else ""),

                    Response = CallFactSetAPI(Endpoint),
                    Data = ConvertStachToTable(Response),
                    NextCursor = Response[meta][pagination][next]?
                in
                    [Data = Data, NextCursor = NextCursor],

            // Accumulate all pages
            AccumulatePages = (accumulated as table, cursor as text) =>
                let
                    Page = GetPage(cursor),
                    Combined = Table.Combine({accumulated, Page[Data]})
                in
                    if Page[NextCursor] = null then
                        Combined
                    else
                        @AccumulatePages(Combined, Page[NextCursor]),

            AllResults = AccumulatePages(#table({}, {}), "")
        in
            AllResults
in
    ExecuteScreen
```

### Integration: Screen then Run PA3

```m
// Combined workflow: Screen → PA3 Analysis
let
    ScreenAndAnalyze = (
        screenName as text,
        pa3ComponentId as text,
        benchmarkId as text,
        startDate as date,
        endDate as date
    ) =>
    let
        // Step 1: Run screening
        ScreenedSecurities = ExecuteScreen(
            screenName,
            Date.ToText(endDate, "yyyyMMdd"),
            null
        ),

        // Extract security identifiers
        SecurityIds = Table.Column(ScreenedSecurities, "Symbol"),
        SecurityIdList = Text.Combine(SecurityIds, ","),

        // Step 2: Create dynamic account from screened securities
        // (This would typically involve creating a temporary portfolio
        // or using the securities directly in PA3)

        // Step 3: Run PA3 analysis
        // Note: PA3 typically works with accounts, not ad-hoc security lists
        // Alternative: Archive screened results to OFDB, then use as PA3 input

        // For direct integration, you might:
        // a) Archive to OFDB first
        // b) Use a pre-configured template that accepts parameters
        // c) Create holdings file programmatically

        PA3Results = RunPA3Calculation(
            pa3ComponentId,
            "Client:ScreenedPortfolio.ACCT",  // Pre-configured account
            benchmarkId,
            startDate,
            endDate,
            "Monthly",
            "B&H",
            "USD",
            "securities"
        ),

        // Step 4: Join screening metadata with PA3 results
        EnrichedResults = Table.NestedJoin(
            PA3Results,
            {"SecurityId"},
            ScreenedSecurities,
            {"Symbol"},
            "ScreeningData",
            JoinKind.LeftOuter
        )
    in
        EnrichedResults
in
    ScreenAndAnalyze
```

### Archive to OFDB for PA3/SPAR Use

```m
// Archive screening results to OFDB for use in PA3/SPAR
let
    ArchiveScreenResults = (
        screenName as text,
        ofdbFilename as text,
        optional archiveDate as text
    ) =>
    let
        RequestBody = [
            data = [
                screenName = screenName,
                archiveOptions = [
                    archiveType = "ofdbSymbols",
                    filename = ofdbFilename,
                    archiveDate = if archiveDate <> null
                        then archiveDate
                        else Date.ToText(Date.From(DateTime.LocalNow()), "yyyyMMdd"),
                    symbolType = "ticker",
                    overwriteData = true
                ]
            ]
        ],

        Response = CallFactSetAPI(
            "/universal-screening/v2/job/archive",
            "POST",
            RequestBody
        ),

        JobId = Response[data][id],

        // Poll for archive completion
        WaitForArchive = PollForCompletion(JobId, "archive")
    in
        [
            Status = "Archived",
            OFDBPath = ofdbFilename,
            JobId = JobId
        ]
in
    ArchiveScreenResults
```

---

## Performance Considerations

| Factor | Recommendation |
|--------|----------------|
| **Large Universes** | Use pagination with 100,000 limit |
| **Long-Running Screens** | Implement timeout (10+ minutes for complex screens) |
| **Rate Limits** | Max 20 requests/second, 10 concurrent jobs |
| **Result Caching** | Cache results client-side; results expire after 6 hours |
| **Incremental Refresh** | Track screening execution by date for incremental loads |

---

## Future Enhancement Ideas

1. **Dynamic Portfolio Creation**
   - Use screening results to dynamically define PA3 accounts
   - Support ad-hoc security lists without pre-configured accounts

2. **Parameter-Driven Dashboards**
   - Expose screening parameters as Power BI slicers
   - Enable interactive what-if analysis

3. **Screening History Tracking**
   - Store screening executions over time
   - Analyze portfolio composition changes

4. **Alert Integration**
   - Monitor screening results for threshold breaches
   - Trigger PA3/SPAR analysis when criteria met

---

## References

- OpenAPI Spec: `/specs/UniversalScreening.v2.yaml`
- SDK (Python): `/code/python/UniversalScreening/v2/`
- SDK (.NET): `/code/dotnet/UniversalScreening/v2/`
- SDK (TypeScript): `/code/typescript/UniversalScreening/v2/`
- SDK (Java): `/code/java/UniversalScreening/v2/`
- Stach Format: https://factset.github.io/stachschema/
