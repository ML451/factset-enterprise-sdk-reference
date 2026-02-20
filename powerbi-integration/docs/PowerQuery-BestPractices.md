# Power Query Best Practices for PA3 & SPAR Integration

## Overview

This document provides Power Query (M language) best practices and reusable patterns for integrating FactSet PA3 and SPAR APIs with Power BI.

---

## Table of Contents

1. [Authentication Setup](#authentication-setup)
2. [API Connection Patterns](#api-connection-patterns)
3. [Async Calculation Handling](#async-calculation-handling)
4. [Data Transformation Patterns](#data-transformation-patterns)
5. [Error Handling](#error-handling)
6. [Performance Optimization](#performance-optimization)
7. [Incremental Refresh](#incremental-refresh)
8. [Complete Examples](#complete-examples)

---

## Authentication Setup

### OAuth 2.0 Authentication (Recommended)

```m
// FactSet OAuth2 Authentication Function
let
    GetFactSetToken = () =>
    let
        ClientId = Text.FromBinary(Extension.Contents("client_id")),
        ClientSecret = Text.FromBinary(Extension.Contents("client_secret")),

        TokenUrl = "https://auth.factset.com/as/token.oauth2",

        TokenResponse = Json.Document(
            Web.Contents(TokenUrl, [
                Headers = [
                    #"Content-Type" = "application/x-www-form-urlencoded"
                ],
                Content = Text.ToBinary(
                    "grant_type=client_credentials" &
                    "&client_id=" & Uri.EscapeDataString(ClientId) &
                    "&client_secret=" & Uri.EscapeDataString(ClientSecret)
                )
            ])
        ),

        AccessToken = TokenResponse[access_token]
    in
        AccessToken
in
    GetFactSetToken
```

### API Key Authentication (Basic Auth)

```m
// Basic Authentication Header
let
    Username = "YOUR_API_KEY_USERNAME",
    Password = "YOUR_API_KEY_PASSWORD",

    Credentials = Text.ToBinary(Username & ":" & Password),
    EncodedCredentials = Binary.ToText(Credentials, BinaryEncoding.Base64),
    AuthHeader = "Basic " & EncodedCredentials
in
    AuthHeader
```

### Secure Credential Storage Pattern

```m
// Parameter-based credential pattern for Power BI Service
let
    // Define as parameters in Power BI
    FactSetApiKey = #"FactSet API Key",  // Parameter name
    FactSetApiSecret = #"FactSet API Secret",  // Parameter name

    GetAuthHeader = () =>
        let
            Credentials = Text.ToBinary(FactSetApiKey & ":" & FactSetApiSecret),
            Encoded = Binary.ToText(Credentials, BinaryEncoding.Base64)
        in
            "Basic " & Encoded
in
    GetAuthHeader
```

---

## API Connection Patterns

### Base URL Configuration

```m
// Shared configuration query
let
    Config = [
        BaseUrl = "https://api.factset.com",
        PAEngineVersion = "v3",
        SPAREngineVersion = "v3",
        DefaultTimeout = #duration(0, 0, 5, 0),  // 5 minutes
        MaxRetries = 3,
        RetryDelaySeconds = 2
    ]
in
    Config
```

### Generic API Call Function

```m
// Reusable API call function with retry logic
let
    CallFactSetAPI = (
        endpoint as text,
        optional method as text,
        optional body as record,
        optional headers as record
    ) =>
    let
        Config = FactSetConfig,
        AuthHeader = GetFactSetAuthHeader(),

        BaseHeaders = [
            #"Authorization" = AuthHeader,
            #"Content-Type" = "application/json",
            #"Accept" = "application/json"
        ],

        MergedHeaders = if headers <> null
            then Record.Combine({BaseHeaders, headers})
            else BaseHeaders,

        HttpMethod = if method <> null then method else "GET",

        Options = [
            Headers = MergedHeaders,
            ManualStatusHandling = {400, 401, 403, 404, 429, 500, 503},
            Timeout = Config[DefaultTimeout]
        ],

        OptionsWithBody = if body <> null and HttpMethod <> "GET"
            then Record.AddField(Options, "Content", Json.FromValue(body))
            else Options,

        Response = Web.Contents(
            Config[BaseUrl] & endpoint,
            OptionsWithBody
        ),

        ResponseMetadata = Value.Metadata(Response),
        StatusCode = ResponseMetadata[Response.Status],

        Result = if StatusCode = 200 or StatusCode = 201 or StatusCode = 202
            then Json.Document(Response)
            else error Error.Record(
                "API Error",
                "Status: " & Text.From(StatusCode),
                Response
            )
    in
        Result
in
    CallFactSetAPI
```

---

## Async Calculation Handling

PA3 and SPAR use asynchronous calculation patterns. Here's how to handle them:

### Submit Calculation and Poll for Results

```m
// PA3 Async Calculation Handler
let
    RunPACalculation = (calculationParams as record) =>
    let
        // Step 1: Submit calculation
        SubmitResponse = CallFactSetAPI(
            "/analytics/engines/pa/v3/calculations",
            "POST",
            [data = calculationParams]
        ),

        // Extract calculation ID from response or Location header
        CalculationId = SubmitResponse[data][calculationid],

        // Step 2: Poll for status
        PollForCompletion = (calcId as text) =>
            let
                MaxAttempts = 60,  // Max polling attempts
                PollIntervalSeconds = 5,

                Poll = (attempt as number) =>
                    let
                        Status = CallFactSetAPI(
                            "/analytics/engines/pa/v3/calculations/" & calcId & "/status"
                        ),

                        CalcStatus = Status[data][status],

                        Result = if CalcStatus = "Completed" then
                            Status
                        else if CalcStatus = "Cancelled" then
                            error "Calculation was cancelled"
                        else if attempt >= MaxAttempts then
                            error "Calculation timed out"
                        else
                            let
                                // Wait before next poll (using Function.InvokeAfter or similar)
                                _ = Function.InvokeAfter(
                                    () => null,
                                    #duration(0, 0, 0, PollIntervalSeconds)
                                )
                            in
                                @Poll(attempt + 1)
                    in
                        Result
            in
                Poll(1),

        CompletedStatus = PollForCompletion(CalculationId),

        // Step 3: Get results for each unit
        Units = Record.FieldNames(CompletedStatus[data][units]),

        Results = List.Transform(Units, each
            CallFactSetAPI(
                "/analytics/engines/pa/v3/calculations/" & CalculationId & "/units/" & _ & "/result"
            )
        )
    in
        Results
in
    RunPACalculation
```

### SPAR Calculation Handler

```m
// SPAR Async Calculation Handler
let
    RunSPARCalculation = (
        componentId as text,
        accountId as text,
        benchmarkId as text,
        startDate as text,
        endDate as text,
        optional frequency as text,
        optional currencyCode as text
    ) =>
    let
        CalculationParams = [
            componentid = componentId,
            accounts = {
                [
                    id = accountId,
                    returntype = "NET",
                    prefix = ""
                ]
            },
            benchmark = [
                id = benchmarkId,
                returntype = "GR"
            ],
            dates = [
                startdate = startDate,
                enddate = endDate,
                frequency = if frequency <> null then frequency else "Monthly"
            ],
            currencyisocode = if currencyCode <> null then currencyCode else "USD"
        ],

        // Submit calculation
        SubmitResponse = CallFactSetAPI(
            "/analytics/engines/spar/v3/calculations",
            "POST",
            [data = CalculationParams]
        ),

        CalculationId = SubmitResponse[data][calculationid],

        // Poll and get results (similar to PA pattern)
        Results = PollAndGetResults(CalculationId, "spar")
    in
        Results
in
    RunSPARCalculation
```

---

## Data Transformation Patterns

### Stach Format to Table Conversion

FactSet returns data in "Stach" format. Convert it to Power BI tables:

```m
// Convert Stach format to Power BI table
let
    ConvertStachToTable = (stachData as record) =>
    let
        // Extract columns metadata
        Columns = stachData[data][columns],
        ColumnNames = List.Transform(Columns, each _[name]),
        ColumnTypes = List.Transform(Columns, each _[type]),

        // Extract row data
        Rows = stachData[data][rows],

        // Convert to table
        DataTable = Table.FromRows(
            List.Transform(Rows, each _[values]),
            ColumnNames
        ),

        // Apply type transformations
        TypedTable = ApplyColumnTypes(DataTable, ColumnNames, ColumnTypes)
    in
        TypedTable,

    ApplyColumnTypes = (table as table, names as list, types as list) =>
    let
        TypeMap = [
            #"STRING" = type text,
            #"REAL" = type number,
            #"INT32" = Int32.Type,
            #"INT64" = Int64.Type,
            #"DATETIME" = type datetime,
            #"DATE" = type date,
            #"BOOL" = type logical
        ],

        Transforms = List.Transform(
            List.Positions(names),
            each {names{_}, Record.FieldOrDefault(TypeMap, types{_}, type any)}
        ),

        Result = Table.TransformColumnTypes(table, Transforms)
    in
        Result
in
    ConvertStachToTable
```

### Flatten Nested API Responses

```m
// Flatten nested performance data
let
    FlattenPerformanceData = (apiResponse as record) =>
    let
        Data = apiResponse[data],

        // Extract base fields
        BaseRecord = [
            CalculationId = Data[calculationid]?,
            Status = Data[status]?
        ],

        // Flatten units
        Units = Data[units]?,
        UnitsList = if Units <> null then
            Record.ToTable(Units)
        else
            #table({"Name", "Value"}, {}),

        // Expand unit details
        ExpandedUnits = Table.ExpandRecordColumn(
            UnitsList,
            "Value",
            {"status", "result", "createtime", "updatetime"}
        )
    in
        ExpandedUnits
in
    FlattenPerformanceData
```

### Transform PA3 Attribution Results

```m
// Transform PA3 attribution results to fact table format
let
    TransformPAAttributionToFacts = (results as list, calculationId as text) =>
    let
        // Combine all unit results
        CombinedResults = List.Accumulate(
            results,
            #table({}, {}),
            (state, current) =>
                let
                    CurrentTable = ConvertStachToTable(current),
                    WithCalcId = Table.AddColumn(
                        CurrentTable,
                        "CalculationId",
                        each calculationId
                    )
                in
                    Table.Combine({state, WithCalcId})
        ),

        // Standardize column names
        RenamedColumns = Table.RenameColumns(CombinedResults, {
            {"Port. Return", "PortfolioReturn"},
            {"Bench. Return", "BenchmarkReturn"},
            {"Active Return", "ActiveReturn"},
            {"Allocation", "AllocationEffect"},
            {"Selection", "SelectionEffect"},
            {"Interaction", "InteractionEffect"}
        }, MissingField.Ignore),

        // Add date key
        WithDateKey = Table.AddColumn(
            RenamedColumns,
            "DateKey",
            each Number.From(Date.ToText([Date], "yyyyMMdd")),
            Int64.Type
        )
    in
        WithDateKey
in
    TransformPAAttributionToFacts
```

---

## Error Handling

### Comprehensive Error Handler

```m
// Robust error handling wrapper
let
    SafeAPICall = (apiFunction as function, params as list) =>
    let
        Result = try Function.Invoke(apiFunction, params),

        HandleError = (error as record) =>
            let
                ErrorType = error[Reason],
                ErrorMessage = error[Message],
                ErrorDetail = error[Detail]?,

                // Log error (in production, send to logging service)
                LogEntry = [
                    Timestamp = DateTime.LocalNow(),
                    ErrorType = ErrorType,
                    Message = ErrorMessage,
                    Detail = ErrorDetail
                ],

                // Return structured error for Power BI
                ErrorTable = #table(
                    {"Error", "Message", "Timestamp"},
                    {{ErrorType, ErrorMessage, DateTime.LocalNow()}}
                )
            in
                ErrorTable
    in
        if Result[HasError] then
            HandleError(Result[Error])
        else
            Result[Value]
in
    SafeAPICall
```

### Rate Limit Handler

```m
// Handle 429 rate limit responses with exponential backoff
let
    CallWithRateLimitHandling = (endpoint as text, method as text, body as record) =>
    let
        MaxRetries = 5,

        CallWithRetry = (attempt as number, delay as number) =>
            let
                Result = try CallFactSetAPI(endpoint, method, body),

                Response = if Result[HasError] then
                    let
                        ErrorCode = Result[Error][Message],
                        IsRateLimit = Text.Contains(ErrorCode, "429")
                    in
                        if IsRateLimit and attempt < MaxRetries then
                            let
                                _ = Function.InvokeAfter(
                                    () => null,
                                    #duration(0, 0, 0, delay)
                                ),
                                NextDelay = delay * 2  // Exponential backoff
                            in
                                @CallWithRetry(attempt + 1, NextDelay)
                        else
                            error Result[Error]
                else
                    Result[Value]
            in
                Response
    in
        CallWithRetry(1, 2)  // Start with 2 second delay
in
    CallWithRateLimitHandling
```

---

## Performance Optimization

### Query Folding Best Practices

```m
// Use native query folding where possible
let
    // GOOD: Filter before expansion
    OptimizedQuery =
        let
            Source = GetPAComponents(),
            FilteredSource = Table.SelectRows(Source, each [Category] = "Performance"),
            ExpandedSource = Table.ExpandRecordColumn(FilteredSource, "Details", {"Name", "Path"})
        in
            ExpandedSource,

    // BAD: Expand then filter (breaks query folding)
    UnoptimizedQuery =
        let
            Source = GetPAComponents(),
            ExpandedSource = Table.ExpandRecordColumn(Source, "Details", {"Name", "Path"}),
            FilteredSource = Table.SelectRows(ExpandedSource, each [Category] = "Performance")
        in
            FilteredSource
in
    OptimizedQuery
```

### Buffering for Multiple Uses

```m
// Buffer tables used multiple times
let
    GetSharedDimensions = () =>
    let
        AccountsRaw = GetAccounts(),
        AccountsBuffered = Table.Buffer(AccountsRaw),

        // Use buffered table in multiple places
        ActiveAccounts = Table.SelectRows(AccountsBuffered, each [IsActive] = true),
        InactiveAccounts = Table.SelectRows(AccountsBuffered, each [IsActive] = false),

        Result = [
            All = AccountsBuffered,
            Active = ActiveAccounts,
            Inactive = InactiveAccounts
        ]
    in
        Result
in
    GetSharedDimensions
```

### Parallel Data Loading Pattern

```m
// Load multiple calculations in parallel
let
    LoadMultipleCalculations = (calculationConfigs as list) =>
    let
        // Submit all calculations first (parallel submission)
        SubmittedCalcs = List.Transform(
            calculationConfigs,
            each SubmitCalculation(_)
        ),

        // Collect calculation IDs
        CalcIds = List.Transform(SubmittedCalcs, each _[calculationid]),

        // Poll all in parallel and combine results
        AllResults = List.Transform(CalcIds, each GetCalculationResult(_)),

        // Combine into single table
        CombinedTable = Table.Combine(AllResults)
    in
        CombinedTable
in
    LoadMultipleCalculations
```

---

## Incremental Refresh

### Setup for Incremental Refresh

```m
// Parameterized query for incremental refresh
let
    // Power BI parameters (set in Power BI Desktop)
    RangeStart = #"RangeStart",  // datetime parameter
    RangeEnd = #"RangeEnd",      // datetime parameter

    GetIncrementalData = (startDate as datetime, endDate as datetime) =>
    let
        StartDateText = Date.ToText(DateTime.Date(startDate), "yyyyMMdd"),
        EndDateText = Date.ToText(DateTime.Date(endDate), "yyyyMMdd"),

        CalculationParams = [
            componentid = "PERFORMANCE_COMPONENT_ID",
            accounts = {[id = "Client:Portfolio.ACCT", holdingsmode = "B&H"]},
            benchmarks = {[id = "BENCH:SP500"]},
            dates = [
                startdate = StartDateText,
                enddate = EndDateText,
                frequency = "Daily"
            ]
        ],

        Results = RunPACalculation(CalculationParams),

        // Filter to ensure only data within range
        FilteredResults = Table.SelectRows(
            Results,
            each [Date] >= DateTime.Date(startDate) and [Date] < DateTime.Date(endDate)
        )
    in
        FilteredResults,

    IncrementalData = GetIncrementalData(RangeStart, RangeEnd)
in
    IncrementalData
```

### Partition Strategy

For optimal incremental refresh:

| Data Type | Partition Strategy | Refresh Policy |
|-----------|-------------------|----------------|
| PA3 Daily Returns | Monthly partitions | Last 7 days full refresh, historical incremental |
| PA3 Holdings | Daily partitions | Daily full refresh |
| SPAR Analysis | Quarterly partitions | Current quarter full, historical incremental |
| Dimensions | No partitioning | Full refresh on schedule |

---

## Complete Examples

### Full PA3 Performance Load

```m
// Complete PA3 Performance data loader
let
    LoadPA3Performance = (
        accountPath as text,
        benchmarkId as text,
        componentPath as text,
        startDate as date,
        endDate as date,
        frequency as text
    ) =>
    let
        // Get component ID from path
        Components = CallFactSetAPI(
            "/analytics/engines/pa/v3/components?document=" & Uri.EscapeDataString(componentPath)
        ),
        ComponentId = Record.FieldNames(Components[data]){0},

        // Build calculation parameters
        CalcParams = [
            componentid = ComponentId,
            accounts = {
                [
                    id = accountPath,
                    holdingsmode = "B&H"
                ]
            },
            benchmarks = {
                [
                    id = benchmarkId
                ]
            },
            dates = [
                startdate = Date.ToText(startDate, "yyyyMMdd"),
                enddate = Date.ToText(endDate, "yyyyMMdd"),
                frequency = frequency
            ],
            currencyisocode = "USD",
            componentdetail = "securities"
        ],

        // Run calculation
        Results = RunPACalculation(CalcParams),

        // Transform to fact table format
        FactTable = TransformPAAttributionToFacts(Results, "PA3_" & Text.From(DateTime.LocalNow()))
    in
        FactTable
in
    LoadPA3Performance
```

### Full SPAR Analysis Load

```m
// Complete SPAR Analysis data loader
let
    LoadSPARAnalysis = (
        accountPath as text,
        benchmarkId as text,
        startDate as date,
        endDate as date
    ) =>
    let
        // Get available SPAR components
        Components = CallFactSetAPI(
            "/analytics/engines/spar/v3/components"
        ),

        // Select risk analysis component
        RiskComponentId = List.First(
            List.Select(
                Record.FieldNames(Components[data]),
                each Text.Contains(Components[data]{_}[name], "Risk")
            )
        ),

        // Build calculation
        CalcParams = [
            componentid = RiskComponentId,
            accounts = {
                [
                    id = accountPath,
                    returntype = "NET",
                    prefix = ""
                ]
            },
            benchmark = [
                id = benchmarkId,
                returntype = "GR"
            ],
            dates = [
                startdate = Date.ToText(startDate, "yyyyMMdd"),
                enddate = Date.ToText(endDate, "yyyyMMdd"),
                frequency = "Monthly"
            ],
            currencyisocode = "USD"
        ],

        // Run calculation
        Results = RunSPARCalculation(CalcParams),

        // Transform results
        FactTable = ConvertStachToTable(Results{0})
    in
        FactTable
in
    LoadSPARAnalysis
```

---

## Summary

Key Power Query best practices for PA3/SPAR:

1. **Use secure credential patterns** - Never hardcode credentials
2. **Handle async calculations properly** - Implement polling with timeout
3. **Convert Stach format** - Transform API responses to proper tables
4. **Implement error handling** - Handle rate limits and API errors gracefully
5. **Optimize performance** - Use buffering, query folding, and parallel loading
6. **Enable incremental refresh** - Partition data appropriately for large datasets

See also:
- [Data Model Design](./PA3-SPAR-DataModel-Design.md)
- [Native Connector Architecture](./NativeConnector-Architecture.md)
