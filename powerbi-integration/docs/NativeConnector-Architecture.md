# Native Power BI Connector Architecture for PA3 & SPAR

## Overview

This document describes the architecture for building a native Power BI custom data connector for FactSet PA3 and SPAR APIs using the Power Query SDK (M Extensions).

---

## Table of Contents

1. [Connector Architecture](#connector-architecture)
2. [Project Structure](#project-structure)
3. [Authentication Implementation](#authentication-implementation)
4. [Navigation Tables](#navigation-tables)
5. [Data Source Functions](#data-source-functions)
6. [Type System Integration](#type-system-integration)
7. [Certification Requirements](#certification-requirements)
8. [Deployment Guide](#deployment-guide)

---

## Connector Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Power BI Desktop / Service                   │
├─────────────────────────────────────────────────────────────────┤
│                    Power Query Engine (M)                        │
├─────────────────────────────────────────────────────────────────┤
│                FactSet Custom Connector (.mez)                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Authentication Module (OAuth 2.0 / API Key)              │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Navigation Table (Data Sources & Functions)              │  │
│  ├────────────────────┬────────────────┬────────────────────┤  │
│  │   PA3 Module       │  SPAR Module   │  Utility Module    │  │
│  │   - Calculations   │  - Calculations│  - Accounts        │  │
│  │   - Components     │  - Components  │  - Currencies      │  │
│  │   - Columns        │  - Benchmarks  │  - Documents       │  │
│  │   - Groups         │  - Frequencies │  - Date Conversion │  │
│  │   - Templates      │                │                    │  │
│  └────────────────────┴────────────────┴────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                     FactSet API (HTTPS)                          │
│                    https://api.factset.com                       │
└─────────────────────────────────────────────────────────────────┘
```

### Component Overview

| Component | Purpose |
|-----------|---------|
| **Authentication Module** | Handles OAuth 2.0 and API Key authentication |
| **Navigation Table** | Provides browsable data source hierarchy |
| **PA3 Module** | PA Engine API integration |
| **SPAR Module** | SPAR Engine API integration |
| **Utility Module** | Shared lookups (accounts, currencies, documents) |

---

## Project Structure

```
FactSet.Connector/
├── FactSet.pq                    # Main connector file
├── FactSet.query.pq              # Test queries
├── FactSet.proj                  # Visual Studio project file
├── resources/
│   ├── FactSet.png               # 64x64 connector icon
│   ├── FactSet16.png             # 16x16 connector icon
│   ├── FactSet24.png             # 24x24 connector icon
│   ├── FactSet32.png             # 32x32 connector icon
│   └── FactSet40.png             # 40x40 connector icon
├── modules/
│   ├── Authentication.pqm        # Auth implementation
│   ├── PAEngine.pqm              # PA3 functions
│   ├── SPAREngine.pqm            # SPAR functions
│   ├── Navigation.pqm            # Navigation table builder
│   └── Utilities.pqm             # Shared utilities
└── FactSet.mez                   # Compiled connector (output)
```

---

## Authentication Implementation

### Connector Definition

```m
// FactSet.pq - Main connector file
section FactSet;

// Connector metadata
[DataSource.Kind="FactSet", Publish="FactSet.Publish"]
shared FactSet.Contents = Value.ReplaceType(
    FactSetImpl,
    FactSetType
);

// Data source kind definition
FactSet = [
    // OAuth 2.0 authentication
    Authentication = [
        OAuth = [
            StartLogin = StartOAuthLogin,
            FinishLogin = FinishOAuthLogin,
            Refresh = RefreshOAuthToken,
            Logout = OAuthLogout,
            Label = "FactSet OAuth"
        ],
        // Fallback to API Key (Basic Auth)
        UsernamePassword = [
            Label = "FactSet API Key"
        ]
    ],
    Label = "FactSet Analytics"
];

// Publish to Power BI connector gallery
FactSet.Publish = [
    Beta = true,
    Category = "Finance",
    ButtonText = { "FactSet Analytics", "Connect to FactSet PA3 and SPAR" },
    LearnMoreUrl = "https://developer.factset.com/",
    SourceImage = FactSet.Icons,
    SourceTypeImage = FactSet.Icons
];

// Icon resources
FactSet.Icons = [
    Icon16 = { Extension.Contents("FactSet16.png"), Extension.Contents("FactSet20.png"), Extension.Contents("FactSet24.png"), Extension.Contents("FactSet32.png") },
    Icon32 = { Extension.Contents("FactSet32.png"), Extension.Contents("FactSet40.png"), Extension.Contents("FactSet48.png"), Extension.Contents("FactSet64.png") }
];
```

### OAuth 2.0 Implementation

```m
// modules/Authentication.pqm

// OAuth configuration
OAuthConfig = [
    AuthorizeUrl = "https://auth.factset.com/as/authorization.oauth2",
    TokenUrl = "https://auth.factset.com/as/token.oauth2",
    ClientId = Extension.CurrentCredential()[client_id],
    RedirectUri = "https://oauth.powerbi.com/views/oauthredirect.html",
    Scope = "openid profile analytics"
];

// Start OAuth login flow
StartOAuthLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = OAuthConfig[AuthorizeUrl] &
            "?client_id=" & OAuthConfig[ClientId] &
            "&redirect_uri=" & Uri.EscapeDataString(OAuthConfig[RedirectUri]) &
            "&response_type=code" &
            "&scope=" & Uri.EscapeDataString(OAuthConfig[Scope]) &
            "&state=" & state
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = OAuthConfig[RedirectUri],
            WindowWidth = 720,
            WindowHeight = 640,
            Context = null
        ];

// Complete OAuth login
FinishOAuthLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri),
        Query = Parts[Query],
        Code = Query[code],

        TokenResponse = Web.Contents(OAuthConfig[TokenUrl], [
            Content = Text.ToBinary(
                "grant_type=authorization_code" &
                "&code=" & Code &
                "&client_id=" & OAuthConfig[ClientId] &
                "&redirect_uri=" & Uri.EscapeDataString(OAuthConfig[RedirectUri])
            ),
            Headers = [
                #"Content-Type" = "application/x-www-form-urlencoded"
            ]
        ]),

        Token = Json.Document(TokenResponse)
    in
        [
            access_token = Token[access_token],
            refresh_token = Token[refresh_token]?,
            token_type = Token[token_type],
            expires_in = Token[expires_in]
        ];

// Refresh expired token
RefreshOAuthToken = (resourceUrl, refresh_token) =>
    let
        TokenResponse = Web.Contents(OAuthConfig[TokenUrl], [
            Content = Text.ToBinary(
                "grant_type=refresh_token" &
                "&refresh_token=" & refresh_token &
                "&client_id=" & OAuthConfig[ClientId]
            ),
            Headers = [
                #"Content-Type" = "application/x-www-form-urlencoded"
            ]
        ]),

        Token = Json.Document(TokenResponse)
    in
        [
            access_token = Token[access_token],
            refresh_token = Token[refresh_token]?,
            token_type = Token[token_type],
            expires_in = Token[expires_in]
        ];

// Logout handler
OAuthLogout = (accessToken) => null;
```

### Authenticated API Call

```m
// Get current credentials and make authenticated call
GetAuthHeaders = () =>
    let
        Credential = Extension.CurrentCredential(),
        AuthType = Credential[AuthenticationKind],

        Headers = if AuthType = "OAuth" then
            [
                #"Authorization" = "Bearer " & Credential[access_token]
            ]
        else  // UsernamePassword (API Key)
            let
                Username = Credential[Username],
                Password = Credential[Password],
                Encoded = Binary.ToText(
                    Text.ToBinary(Username & ":" & Password),
                    BinaryEncoding.Base64
                )
            in
                [
                    #"Authorization" = "Basic " & Encoded
                ]
    in
        Headers;

// Authenticated API call
CallAPI = (endpoint as text, optional method as text, optional body as record) =>
    let
        BaseUrl = "https://api.factset.com",
        AuthHeaders = GetAuthHeaders(),

        Headers = Record.Combine({
            AuthHeaders,
            [
                #"Content-Type" = "application/json",
                #"Accept" = "application/json"
            ]
        }),

        Options = [
            Headers = Headers,
            ManualStatusHandling = {400, 401, 403, 404, 429, 500, 503}
        ],

        OptionsWithBody = if body <> null then
            Record.AddField(Options, "Content", Json.FromValue(body))
        else
            Options,

        Response = Web.Contents(BaseUrl & endpoint, OptionsWithBody),
        Metadata = Value.Metadata(Response),
        StatusCode = Metadata[Response.Status],

        Result = if StatusCode >= 200 and StatusCode < 300 then
            Json.Document(Response)
        else
            error Error.Record("FactSet API Error", "Status " & Text.From(StatusCode), Response)
    in
        Result;
```

---

## Navigation Tables

### Main Navigation Structure

```m
// modules/Navigation.pqm

// Build main navigation table
BuildNavigationTable = () =>
    let
        NavTable = #table(
            {"Name", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                // PA3 Section
                {"PA3 Engine", PA3Navigation(), "Folder", "Folder", false},

                // SPAR Section
                {"SPAR Engine", SPARNavigation(), "Folder", "Folder", false},

                // Shared Lookups
                {"Accounts", GetAccountsNavigation(), "Folder", "Folder", false},
                {"Currencies", GetCurrencies, "Function", "Function", true},

                // Custom Functions
                {"Run PA3 Calculation", RunPA3Calculation, "Function", "Function", true},
                {"Run SPAR Calculation", RunSPARCalculation, "Function", "Function", true}
            }
        ),

        FormattedNav = Table.FormatAsNavigationTable(NavTable)
    in
        FormattedNav;

// Format as Power BI navigation table
Table.FormatAsNavigationTable = (table as table) as table =>
    let
        TableType = Value.Type(table),
        NewTableType = Type.AddTableKey(TableType, {"Name"}, true) meta [
            NavigationTable.NameColumn = "Name",
            NavigationTable.DataColumn = "Data",
            NavigationTable.ItemKindColumn = "ItemKind",
            NavigationTable.IsLeafColumn = "IsLeaf",
            Preview.DelayColumn = "Data"
        ],
        Result = Value.ReplaceType(table, NewTableType)
    in
        Result;

// PA3 sub-navigation
PA3Navigation = () =>
    let
        NavTable = #table(
            {"Name", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Components", GetPA3Components, "Function", "Function", true},
                {"Columns", GetPA3Columns, "Function", "Function", true},
                {"Column Statistics", GetPA3ColumnStatistics, "Function", "Function", true},
                {"Groups", GetPA3Groups, "Function", "Function", true},
                {"Grouping Frequencies", GetPA3GroupingFrequencies, "Function", "Function", true},
                {"Frequencies", GetPA3Frequencies, "Function", "Function", true},
                {"Pricing Sources", GetPA3PricingSources, "Function", "Function", true},
                {"Documents", GetPA3DocumentsNavigation(), "Folder", "Folder", false},
                {"Linked Templates", GetPA3LinkedTemplates, "Function", "Function", true},
                {"Unlinked Templates", GetPA3UnlinkedTemplates, "Function", "Function", true}
            }
        ),

        FormattedNav = Table.FormatAsNavigationTable(NavTable)
    in
        FormattedNav;

// SPAR sub-navigation
SPARNavigation = () =>
    let
        NavTable = #table(
            {"Name", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Components", GetSPARComponents, "Function", "Function", true},
                {"Benchmarks", GetSPARBenchmarks, "Function", "Function", true},
                {"Frequencies", GetSPARFrequencies, "Function", "Function", true},
                {"Documents", GetSPARDocumentsNavigation(), "Folder", "Folder", false}
            }
        ),

        FormattedNav = Table.FormatAsNavigationTable(NavTable)
    in
        FormattedNav;
```

---

## Data Source Functions

### PA3 Engine Functions

```m
// modules/PAEngine.pqm

// Get PA3 Components
GetPA3Components = (optional documentPath as text) =>
    let
        Endpoint = if documentPath <> null then
            "/analytics/engines/pa/v3/components?document=" & Uri.EscapeDataString(documentPath)
        else
            "/analytics/engines/pa/v3/components",

        Response = CallAPI(Endpoint),
        Data = Response[data],

        // Convert record to table
        ComponentsList = Record.ToTable(Data),
        Expanded = Table.ExpandRecordColumn(ComponentsList, "Value", {"name", "category", "path"}),
        Renamed = Table.RenameColumns(Expanded, {
            {"Name", "ComponentId"},
            {"name", "ComponentName"},
            {"category", "Category"},
            {"path", "Path"}
        }),
        Typed = Table.TransformColumnTypes(Renamed, {
            {"ComponentId", type text},
            {"ComponentName", type text},
            {"Category", type text},
            {"Path", type text}
        })
    in
        Typed;

// Get PA3 Columns
GetPA3Columns = (optional name as text, optional category as text, optional directory as text) =>
    let
        QueryParams = List.RemoveNulls({
            if name <> null then "name=" & Uri.EscapeDataString(name) else null,
            if category <> null then "category=" & Uri.EscapeDataString(category) else null,
            if directory <> null then "directory=" & Uri.EscapeDataString(directory) else null
        }),
        QueryString = if List.Count(QueryParams) > 0 then "?" & Text.Combine(QueryParams, "&") else "",

        Endpoint = "/analytics/engines/pa/v3/columns" & QueryString,
        Response = CallAPI(Endpoint),
        Data = Response[data],

        ColumnsList = Record.ToTable(Data),
        Expanded = Table.ExpandRecordColumn(ColumnsList, "Value", {"name", "category", "directory"}),
        Renamed = Table.RenameColumns(Expanded, {
            {"Name", "ColumnId"},
            {"name", "ColumnName"},
            {"category", "Category"},
            {"directory", "Directory"}
        })
    in
        Renamed;

// Run PA3 Calculation (main function)
RunPA3Calculation = (
    componentId as text,
    accountId as text,
    benchmarkId as text,
    startDate as date,
    endDate as date,
    optional frequency as text,
    optional holdingsMode as text,
    optional currencyCode as text,
    optional componentDetail as text
) as table =>
    let
        // Build calculation request
        CalcRequest = [
            data = [
                componentid = componentId,
                accounts = {
                    [
                        id = accountId,
                        holdingsmode = if holdingsMode <> null then holdingsMode else "B&H"
                    ]
                },
                benchmarks = {
                    [id = benchmarkId]
                },
                dates = [
                    startdate = Date.ToText(startDate, "yyyyMMdd"),
                    enddate = Date.ToText(endDate, "yyyyMMdd"),
                    frequency = if frequency <> null then frequency else "Monthly"
                ],
                currencyisocode = if currencyCode <> null then currencyCode else "USD",
                componentdetail = if componentDetail <> null then componentDetail else "groups"
            ]
        ],

        // Submit calculation
        SubmitResponse = CallAPI(
            "/analytics/engines/pa/v3/calculations",
            "POST",
            CalcRequest
        ),

        // Handle response - could be immediate (201) or queued (202)
        ResponseMeta = Value.Metadata(SubmitResponse),

        Result = if ResponseMeta[Response.Status]? = 201 then
            // Immediate result
            ProcessCalculationResult(SubmitResponse)
        else
            // Queued - need to poll
            let
                CalcId = SubmitResponse[data][calculationid],
                FinalResult = PollForCalculationResult(CalcId, "pa")
            in
                FinalResult
    in
        Result;

// Poll for calculation completion
PollForCalculationResult = (calculationId as text, engine as text) =>
    let
        BaseEndpoint = "/analytics/engines/" & engine & "/v3/calculations/" & calculationId,

        // Recursive polling function
        Poll = (attempt as number) =>
            let
                StatusResponse = CallAPI(BaseEndpoint & "/status"),
                Status = StatusResponse[data][status],

                Result = if Status = "Completed" then
                    // Get results for all units
                    let
                        Units = Record.FieldNames(StatusResponse[data][units]),
                        Results = List.Transform(
                            Units,
                            each CallAPI(BaseEndpoint & "/units/" & _ & "/result")
                        ),
                        Combined = ProcessMultipleResults(Results)
                    in
                        Combined
                else if Status = "Cancelled" then
                    error Error.Record("Calculation Cancelled", calculationId, null)
                else if attempt >= 120 then  // 10 minute timeout (5s * 120)
                    error Error.Record("Calculation Timeout", "Exceeded 10 minutes", null)
                else
                    let
                        _ = Function.InvokeAfter(() => null, #duration(0, 0, 0, 5))
                    in
                        @Poll(attempt + 1)
            in
                Result
    in
        Poll(1);

// Process Stach results to table
ProcessCalculationResult = (response as record) as table =>
    let
        // Handle Stach format
        Data = response[data],
        Tables = Data[tables]?,

        Result = if Tables <> null then
            // New Stach format with tables
            let
                FirstTable = Tables{0},
                Columns = FirstTable[definition][columns],
                Rows = FirstTable[data][rows],

                ColumnNames = List.Transform(Columns, each _[name]),
                TableData = Table.FromRows(
                    List.Transform(Rows, each _[values]),
                    ColumnNames
                )
            in
                TableData
        else
            // Legacy format
            Table.FromRecords({Data})
    in
        Result;
```

### SPAR Engine Functions

```m
// modules/SPAREngine.pqm

// Get SPAR Components
GetSPARComponents = (optional documentPath as text) =>
    let
        Endpoint = if documentPath <> null then
            "/analytics/engines/spar/v3/components?document=" & Uri.EscapeDataString(documentPath)
        else
            "/analytics/engines/spar/v3/components",

        Response = CallAPI(Endpoint),
        Data = Response[data],

        ComponentsList = Record.ToTable(Data),
        Expanded = Table.ExpandRecordColumn(ComponentsList, "Value", {"name", "category", "path"}),
        Renamed = Table.RenameColumns(Expanded, {
            {"Name", "ComponentId"},
            {"name", "ComponentName"},
            {"category", "Category"},
            {"path", "Path"}
        })
    in
        Renamed;

// Get SPAR Benchmarks
GetSPARBenchmarks = () =>
    let
        Response = CallAPI("/analytics/engines/spar/v3/benchmarks"),
        Data = Response[data],

        BenchmarksList = Record.ToTable(Data),
        Expanded = Table.ExpandRecordColumn(BenchmarksList, "Value", {"name", "id"}),
        Renamed = Table.RenameColumns(Expanded, {
            {"Name", "BenchmarkKey"},
            {"name", "BenchmarkName"},
            {"id", "BenchmarkId"}
        })
    in
        Renamed;

// Get Account Returns Type
GetAccountReturnsType = (accountPath as text) =>
    let
        Endpoint = "/analytics/engines/spar/v3/accounts/" &
            Uri.EscapeDataString(accountPath) & "/returns-type",

        Response = CallAPI(Endpoint),
        ReturnsTypes = Response[data][returnsType],

        Table = Table.FromRecords(ReturnsTypes)
    in
        Table;

// Run SPAR Calculation
RunSPARCalculation = (
    componentId as text,
    accountId as text,
    benchmarkId as text,
    startDate as date,
    endDate as date,
    optional returnType as text,
    optional frequency as text,
    optional currencyCode as text
) as table =>
    let
        CalcRequest = [
            data = [
                componentid = componentId,
                accounts = {
                    [
                        id = accountId,
                        returntype = if returnType <> null then returnType else "NET",
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
                    frequency = if frequency <> null then frequency else "Monthly"
                ],
                currencyisocode = if currencyCode <> null then currencyCode else "USD"
            ]
        ],

        SubmitResponse = CallAPI(
            "/analytics/engines/spar/v3/calculations",
            "POST",
            CalcRequest
        ),

        CalcId = SubmitResponse[data][calculationid],
        FinalResult = PollForCalculationResult(CalcId, "spar")
    in
        FinalResult;
```

---

## Type System Integration

### Function Type Definitions

```m
// Type definitions for documentation and IntelliSense

// PA3 Calculation function type
RunPA3CalculationType = type function (
    componentId as (type text meta [
        Documentation.FieldCaption = "Component ID",
        Documentation.FieldDescription = "PA3 component identifier"
    ]),
    accountId as (type text meta [
        Documentation.FieldCaption = "Account ID",
        Documentation.FieldDescription = "Account path (e.g., 'Client:Portfolio.ACCT')"
    ]),
    benchmarkId as (type text meta [
        Documentation.FieldCaption = "Benchmark ID",
        Documentation.FieldDescription = "Benchmark identifier (e.g., 'BENCH:SP500')"
    ]),
    startDate as (type date meta [
        Documentation.FieldCaption = "Start Date",
        Documentation.FieldDescription = "Analysis start date"
    ]),
    endDate as (type date meta [
        Documentation.FieldCaption = "End Date",
        Documentation.FieldDescription = "Analysis end date"
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.FieldDescription = "Data frequency",
        Documentation.AllowedValues = {"Daily", "Weekly", "Monthly", "Quarterly", "Annually"}
    ]),
    optional holdingsMode as (type text meta [
        Documentation.FieldCaption = "Holdings Mode",
        Documentation.FieldDescription = "How to handle holdings",
        Documentation.AllowedValues = {"B&H", "TBR", "OMS", "EXT", "VLT"}
    ]),
    optional currencyCode as (type text meta [
        Documentation.FieldCaption = "Currency",
        Documentation.FieldDescription = "ISO currency code (default: USD)"
    ]),
    optional componentDetail as (type text meta [
        Documentation.FieldCaption = "Detail Level",
        Documentation.FieldDescription = "Level of detail in results",
        Documentation.AllowedValues = {"securities", "groups", "groupsall", "totals"}
    ])
) as table meta [
    Documentation.Name = "Run PA3 Calculation",
    Documentation.LongDescription = "Executes a PA3 performance attribution calculation and returns results as a table.",
    Documentation.Examples = {[
        Description = "Basic PA3 calculation",
        Code = "RunPA3Calculation(""PERF_ATTRIB"", ""Client:MyPortfolio.ACCT"", ""BENCH:SP500"", #date(2023,1,1), #date(2023,12,31))",
        Result = "Table with attribution results"
    ]}
];

// SPAR Calculation function type
RunSPARCalculationType = type function (
    componentId as (type text meta [
        Documentation.FieldCaption = "Component ID",
        Documentation.FieldDescription = "SPAR component identifier"
    ]),
    accountId as (type text meta [
        Documentation.FieldCaption = "Account ID",
        Documentation.FieldDescription = "Account path"
    ]),
    benchmarkId as (type text meta [
        Documentation.FieldCaption = "Benchmark ID",
        Documentation.FieldDescription = "Benchmark identifier"
    ]),
    startDate as (type date meta [
        Documentation.FieldCaption = "Start Date"
    ]),
    endDate as (type date meta [
        Documentation.FieldCaption = "End Date"
    ]),
    optional returnType as (type text meta [
        Documentation.FieldCaption = "Return Type",
        Documentation.AllowedValues = {"GR", "NET"}
    ]),
    optional frequency as (type text meta [
        Documentation.FieldCaption = "Frequency",
        Documentation.AllowedValues = {"Daily", "Weekly", "Monthly", "Quarterly", "Annually"}
    ]),
    optional currencyCode as (type text meta [
        Documentation.FieldCaption = "Currency"
    ])
) as table meta [
    Documentation.Name = "Run SPAR Calculation",
    Documentation.LongDescription = "Executes a SPAR style, performance, and risk analysis calculation."
];
```

---

## Certification Requirements

### Microsoft Certification Checklist

For official Power BI connector certification:

| Requirement | Implementation |
|-------------|---------------|
| **Security** | OAuth 2.0 with PKCE, secure credential storage |
| **Error Handling** | Comprehensive error messages, rate limit handling |
| **Documentation** | Full function documentation with examples |
| **Performance** | Query folding where possible, efficient pagination |
| **Testing** | Unit tests for all functions |
| **Compliance** | GDPR data handling, no PII logging |

### Required Files for Certification

```
submission/
├── FactSet.mez                    # Compiled connector
├── FactSet.pq                     # Source code
├── TestReport.md                  # Test results
├── Documentation.md               # User documentation
├── SecurityReview.md              # Security assessment
├── PrivacyPolicy.url              # Link to privacy policy
└── SupportContact.md              # Support information
```

---

## Deployment Guide

### Local Development

1. Install Power Query SDK for Visual Studio
2. Clone connector project
3. Build solution (`Ctrl+Shift+B`)
4. Copy `.mez` file to `Documents\Power BI Desktop\Custom Connectors`
5. Enable custom connectors in Power BI Desktop options

### Enterprise Deployment

```powershell
# Deploy to Power BI Gateway
$connectorPath = "C:\Path\To\FactSet.mez"
$gatewayPath = "C:\Program Files\On-premises data gateway\Custom Connectors"

Copy-Item $connectorPath -Destination $gatewayPath

# Restart gateway service
Restart-Service "PBIEgwService"
```

### Power BI Service Configuration

1. Upload connector to organizational data connectors
2. Configure OAuth app registration in Azure AD
3. Set up gateway data source with credentials
4. Enable connector in tenant settings

---

## Summary

This native connector architecture provides:

- **Secure Authentication**: OAuth 2.0 and API Key support
- **Comprehensive Navigation**: Browse PA3 and SPAR resources
- **Async Calculation Handling**: Proper polling for long-running calculations
- **Type Safety**: Full type documentation for IntelliSense
- **Enterprise Ready**: Certification-ready architecture

See also:
- [Data Model Design](./PA3-SPAR-DataModel-Design.md)
- [Power Query Best Practices](./PowerQuery-BestPractices.md)
