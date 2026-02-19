// ============================================================================
// MULTI-PORTFOLIO ATTRIBUTION REPORT - USAGE EXAMPLES
// Power Query (M) Implementation Patterns
// ============================================================================

// ============================================================================
// EXAMPLE 1: Single Portfolio Attribution Report
// ============================================================================

let
    // Configuration
    PortfolioConfig = [
        PortfolioId = "Client:Growth_Portfolio.ACCT",
        PortfolioName = "Growth Strategy",
        BenchmarkId = "BENCH:SP500",
        BenchmarkName = "S&P 500",
        ComponentId = "PA3_PERFORMANCE_ATTRIBUTION",
        StartDate = #date(2024, 1, 1),
        EndDate = #date(2024, 12, 31),
        Frequency = "Monthly"
    ],

    // Call PA3 API (async)
    CalcRequest = [
        data = [
            componentid = PortfolioConfig[ComponentId],
            accounts = {[
                id = PortfolioConfig[PortfolioId],
                holdingsmode = "B&H"
            ]},
            benchmarks = {[
                id = PortfolioConfig[BenchmarkId]
            ]},
            dates = [
                startdate = Date.ToText(PortfolioConfig[StartDate], "yyyyMMdd"),
                enddate = Date.ToText(PortfolioConfig[EndDate], "yyyyMMdd"),
                frequency = PortfolioConfig[Frequency]
            ],
            currencyisocode = "USD",
            componentdetail = "groups"
        ]
    ],

    // Submit and get results (using functions from StachTransformations.pq)
    ApiResponse = SubmitPA3Calculation(CalcRequest),

    // Transform using optimized pipeline
    TransformedData = TransformAttributionReport(
        ApiResponse,
        PortfolioConfig[PortfolioId],
        PortfolioConfig[PortfolioName],
        PortfolioConfig[BenchmarkId],
        PortfolioConfig[BenchmarkName]
    ),

    // Validate results
    Validation = ValidateAttributionData(TransformedData),

    // Final output
    Output = if Validation[IsValid] then
        TransformedData
    else
        error Error.Record(
            "Data Validation Failed",
            Text.Combine(Validation[Warnings], "; "),
            Validation
        )
in
    Output,


// ============================================================================
// EXAMPLE 2: Multi-Portfolio Comparative Analysis
// ============================================================================

let
    // Define multiple portfolios
    Portfolios = {
        [
            PortfolioId = "Client:Growth.ACCT",
            PortfolioName = "Growth Strategy",
            BenchmarkId = "BENCH:RUSSELL1000G",
            BenchmarkName = "Russell 1000 Growth"
        ],
        [
            PortfolioId = "Client:Value.ACCT",
            PortfolioName = "Value Strategy",
            BenchmarkId = "BENCH:RUSSELL1000V",
            BenchmarkName = "Russell 1000 Value"
        ],
        [
            PortfolioId = "Client:Core.ACCT",
            PortfolioName = "Core Strategy",
            BenchmarkId = "BENCH:SP500",
            BenchmarkName = "S&P 500"
        ],
        [
            PortfolioId = "Client:SmallCap.ACCT",
            PortfolioName = "Small Cap Strategy",
            BenchmarkId = "BENCH:RUSSELL2000",
            BenchmarkName = "Russell 2000"
        ]
    },

    // Common parameters
    CommonParams = [
        ComponentId = "PA3_SECTOR_ATTRIBUTION",
        StartDate = #date(2024, 1, 1),
        EndDate = #date(2024, 12, 31),
        Frequency = "Monthly",
        ComponentDetail = "groups"
    ],

    // Submit all calculations in parallel (conceptually)
    CalculationResults = List.Transform(
        Portfolios,
        each
            let
                CalcRequest = [
                    data = [
                        componentid = CommonParams[ComponentId],
                        accounts = {[
                            id = _[PortfolioId],
                            holdingsmode = "B&H"
                        ]},
                        benchmarks = {[
                            id = _[BenchmarkId]
                        ]},
                        dates = [
                            startdate = Date.ToText(CommonParams[StartDate], "yyyyMMdd"),
                            enddate = Date.ToText(CommonParams[EndDate], "yyyyMMdd"),
                            frequency = CommonParams[Frequency]
                        ],
                        currencyisocode = "USD",
                        componentdetail = CommonParams[ComponentDetail]
                    ]
                ]
            in
                SubmitPA3Calculation(CalcRequest)
    ),

    // Transform all results using multi-portfolio pipeline
    CombinedResults = TransformMultiPortfolioAttribution(
        CalculationResults,
        Portfolios
    ),

    // Add calculated comparison metrics
    WithComparisons = Table.AddColumn(
        CombinedResults,
        "RankByActiveReturn",
        each
            let
                CurrentDate = [Date],
                CurrentGroup = [GroupName],
                SameGroupDate = Table.SelectRows(
                    CombinedResults,
                    each [Date] = CurrentDate and [GroupName] = CurrentGroup
                ),
                Ranked = Table.Sort(SameGroupDate, {{"ActiveReturn", Order.Descending}}),
                Position = List.PositionOf(Table.Column(Ranked, "PortfolioId"), [PortfolioId]) + 1
            in
                Position,
        Int64.Type
    )
in
    WithComparisons,


// ============================================================================
// EXAMPLE 3: Time-Series Attribution with Period Comparison
// ============================================================================

let
    // Portfolio configuration
    Portfolio = [
        PortfolioId = "Client:Main.ACCT",
        BenchmarkId = "BENCH:SP500"
    ],

    // Define comparison periods
    Periods = {
        [Name = "YTD 2024", StartDate = #date(2024, 1, 1), EndDate = #date(2024, 12, 31)],
        [Name = "YTD 2023", StartDate = #date(2023, 1, 1), EndDate = #date(2023, 12, 31)],
        [Name = "Q4 2024", StartDate = #date(2024, 10, 1), EndDate = #date(2024, 12, 31)],
        [Name = "Q4 2023", StartDate = #date(2023, 10, 1), EndDate = #date(2023, 12, 31)]
    },

    // Run calculations for each period
    PeriodResults = List.Transform(
        Periods,
        each
            let
                Period = _,
                CalcRequest = [
                    data = [
                        componentid = "PA3_ATTRIBUTION",
                        accounts = {[id = Portfolio[PortfolioId], holdingsmode = "B&H"]},
                        benchmarks = {[id = Portfolio[BenchmarkId]]},
                        dates = [
                            startdate = Date.ToText(Period[StartDate], "yyyyMMdd"),
                            enddate = Date.ToText(Period[EndDate], "yyyyMMdd"),
                            frequency = "Single"  // Single period for comparison
                        ],
                        currencyisocode = "USD",
                        componentdetail = "groups"
                    ]
                ],

                ApiResponse = SubmitPA3Calculation(CalcRequest),
                Parsed = ParseStachResponse(ApiResponse),
                Standardized = StandardizeAttributionColumns(Parsed),

                // Add period metadata
                WithPeriod = Table.AddColumn(Standardized, "PeriodName", each Period[Name], type text),
                WithStart = Table.AddColumn(WithPeriod, "PeriodStart", each Period[StartDate], type date),
                WithEnd = Table.AddColumn(WithStart, "PeriodEnd", each Period[EndDate], type date)
            in
                WithEnd
    ),

    // Combine all periods
    AllPeriods = Table.Combine(PeriodResults),

    // Pivot for period comparison
    PivotedByPeriod = Table.Pivot(
        AllPeriods,
        List.Distinct(Table.Column(AllPeriods, "PeriodName")),
        "PeriodName",
        "ActiveReturn",
        List.Sum
    )
in
    PivotedByPeriod,


// ============================================================================
// EXAMPLE 4: Hierarchical Sector/Industry Drill-Down
// ============================================================================

let
    // Get attribution data with group hierarchy
    ApiResponse = SubmitPA3Calculation([
        data = [
            componentid = "PA3_GICS_ATTRIBUTION",
            accounts = {[id = "Client:Portfolio.ACCT", holdingsmode = "B&H"]},
            benchmarks = {[id = "BENCH:SP500"]},
            dates = [startdate = "20240101", enddate = "20241231", frequency = "Monthly"],
            currencyisocode = "USD",
            componentdetail = "groupsall"  // Get all group levels
        ]
    ]),

    // Parse and standardize
    ParsedData = ParseStachResponse(ApiResponse),
    StandardizedData = StandardizeAttributionColumns(ParsedData),

    // Expand GICS hierarchy (Sector|Industry Group|Industry|Sub-Industry)
    WithHierarchy = ExpandGroupHierarchy(StandardizedData, "GroupName"),

    // Rename hierarchy levels to GICS names
    RenamedLevels = Table.RenameColumns(WithHierarchy, {
        {"GroupLevel1", "Sector"},
        {"GroupLevel2", "IndustryGroup"},
        {"GroupLevel3", "Industry"},
        {"GroupLevel4", "SubIndustry"}
    }, MissingField.Ignore),

    // Create aggregated views at each level
    SectorLevel = AggregateToGroupLevel(
        RenamedLevels,
        {"Date", "Sector"},
        {"PortfolioReturn", "BenchmarkReturn", "ActiveReturn",
         "AllocationEffect", "SelectionEffect", "TotalEffect"}
    ),

    IndustryGroupLevel = AggregateToGroupLevel(
        RenamedLevels,
        {"Date", "Sector", "IndustryGroup"},
        {"PortfolioReturn", "BenchmarkReturn", "ActiveReturn",
         "AllocationEffect", "SelectionEffect", "TotalEffect"}
    ),

    // Add level indicator for drill-down visualization
    SectorWithLevel = Table.AddColumn(SectorLevel, "HierarchyLevel", each "Sector", type text),
    IndustryWithLevel = Table.AddColumn(IndustryGroupLevel, "HierarchyLevel", each "Industry Group", type text),

    // Combine for hierarchical visualization
    CombinedHierarchy = Table.Combine({SectorWithLevel, IndustryWithLevel})
in
    CombinedHierarchy,


// ============================================================================
// EXAMPLE 5: Incremental Refresh Pattern
// ============================================================================

let
    // Power BI incremental refresh parameters
    RangeStart = #"RangeStart",  // datetime parameter
    RangeEnd = #"RangeEnd",      // datetime parameter

    // Convert to dates
    StartDate = DateTime.Date(RangeStart),
    EndDate = DateTime.Date(RangeEnd),

    // Build request for date range
    CalcRequest = [
        data = [
            componentid = "PA3_DAILY_ATTRIBUTION",
            accounts = {[id = "Client:Portfolio.ACCT", holdingsmode = "B&H"]},
            benchmarks = {[id = "BENCH:SP500"]},
            dates = [
                startdate = Date.ToText(StartDate, "yyyyMMdd"),
                enddate = Date.ToText(EndDate, "yyyyMMdd"),
                frequency = "Daily"
            ],
            currencyisocode = "USD",
            componentdetail = "groups"
        ]
    ],

    // Execute and transform
    ApiResponse = SubmitPA3Calculation(CalcRequest),

    TransformedData = TransformAttributionReport(
        ApiResponse,
        "Client:Portfolio.ACCT",
        "Main Portfolio",
        "BENCH:SP500",
        "S&P 500"
    ),

    // Filter to exact range (defensive)
    FilteredData = Table.SelectRows(
        TransformedData,
        each [Date] >= StartDate and [Date] < EndDate
    ),

    // Add partition key for incremental refresh
    WithPartitionKey = Table.AddColumn(
        FilteredData,
        "PartitionKey",
        each Date.Year([Date]) * 100 + Date.Month([Date]),
        Int64.Type
    )
in
    WithPartitionKey,


// ============================================================================
// EXAMPLE 6: Security-Level Attribution with Holdings
// ============================================================================

let
    // Get security-level attribution
    AttributionResponse = SubmitPA3Calculation([
        data = [
            componentid = "PA3_SECURITY_ATTRIBUTION",
            accounts = {[id = "Client:Portfolio.ACCT", holdingsmode = "B&H"]},
            benchmarks = {[id = "BENCH:SP500"]},
            dates = [startdate = "20241201", enddate = "20241231", frequency = "Monthly"],
            currencyisocode = "USD",
            componentdetail = "securities"  // Security level detail
        ]
    ]),

    // Parse attribution data
    AttributionData = ParseStachResponse(AttributionResponse),
    StandardizedAttribution = StandardizeAttributionColumns(AttributionData),

    // Add derived metrics
    WithDerived = AddDerivedAttributionMetrics(StandardizedAttribution),

    // Identify top/bottom contributors
    Sorted = Table.Sort(WithDerived, {{"ActiveContribution", Order.Descending}}),
    Ranked = Table.AddIndexColumn(Sorted, "Rank", 1, 1, Int64.Type),

    // Flag top and bottom 10
    WithFlags = Table.AddColumn(
        Ranked,
        "ContributorCategory",
        each if [Rank] <= 10 then "Top 10"
             else if [Rank] > Table.RowCount(Ranked) - 10 then "Bottom 10"
             else "Middle",
        type text
    ),

    // Add cumulative contribution
    WithCumulative = Table.AddColumn(
        WithFlags,
        "CumulativeContribution",
        each List.Sum(List.FirstN(Table.Column(Sorted, "ActiveContribution"), [Rank])),
        type number
    )
in
    WithCumulative,


// ============================================================================
// EXAMPLE 7: Error Handling and Retry Pattern
// ============================================================================

let
    // Configuration
    MaxRetries = 3,
    RetryDelaySeconds = 2,

    // Robust API call with retry
    CallWithRetry = (request as record, attempt as number) =>
        let
            Result = try SubmitPA3Calculation(request),

            Output = if Result[HasError] then
                let
                    ErrorMessage = Result[Error][Message],
                    IsRetryable = Text.Contains(ErrorMessage, "429") or
                                  Text.Contains(ErrorMessage, "503") or
                                  Text.Contains(ErrorMessage, "timeout"),
                    ShouldRetry = IsRetryable and attempt < MaxRetries
                in
                    if ShouldRetry then
                        let
                            Delay = Number.Power(RetryDelaySeconds, attempt),
                            _ = Function.InvokeAfter(
                                () => null,
                                #duration(0, 0, 0, Delay)
                            )
                        in
                            @CallWithRetry(request, attempt + 1)
                    else
                        error Result[Error]
            else
                Result[Value]
        in
            Output,

    // Example usage
    CalcRequest = [
        data = [
            componentid = "PA3_ATTRIBUTION",
            accounts = {[id = "Client:Portfolio.ACCT", holdingsmode = "B&H"]},
            benchmarks = {[id = "BENCH:SP500"]},
            dates = [startdate = "20240101", enddate = "20241231", frequency = "Monthly"],
            currencyisocode = "USD"
        ]
    ],

    // Call with retry logic
    ApiResponse = CallWithRetry(CalcRequest, 1),

    // Transform with error handling
    FinalResult = SafeTransform(
        (response) => TransformAttributionReport(
            response,
            "Client:Portfolio.ACCT",
            "Portfolio",
            "BENCH:SP500",
            "S&P 500"
        ),
        ApiResponse,
        #table(
            {"Error", "Message", "Timestamp"},
            {{"TransformError", "Failed to transform attribution data", DateTime.LocalNow()}}
        )
    )
in
    FinalResult,


// ============================================================================
// EXAMPLE 8: Custom Fact Table Builder
// ============================================================================

let
    // Build fact table with surrogate keys for star schema
    BuildAttributionFactTable = (
        attributionData as table,
        dimDate as table,
        dimAccount as table,
        dimSecurity as table,
        dimGroup as table
    ) as table =>
        let
            // Join to get DateKey
            WithDateKey = Table.NestedJoin(
                attributionData,
                {"Date"},
                dimDate,
                {"Date"},
                "_DateDim",
                JoinKind.LeftOuter
            ),
            ExpandDateKey = Table.ExpandTableColumn(
                WithDateKey,
                "_DateDim",
                {"DateKey"},
                {"DateKey"}
            ),

            // Join to get AccountKey
            WithAccountKey = Table.NestedJoin(
                ExpandDateKey,
                {"PortfolioId"},
                dimAccount,
                {"AccountId"},
                "_AccountDim",
                JoinKind.LeftOuter
            ),
            ExpandAccountKey = Table.ExpandTableColumn(
                WithAccountKey,
                "_AccountDim",
                {"AccountKey"},
                {"AccountKey"}
            ),

            // Join to get SecurityKey (if security-level data)
            WithSecurityKey = if List.Contains(Table.ColumnNames(ExpandAccountKey), "SecurityName") then
                let
                    Joined = Table.NestedJoin(
                        ExpandAccountKey,
                        {"SecurityName"},
                        dimSecurity,
                        {"SecurityName"},
                        "_SecurityDim",
                        JoinKind.LeftOuter
                    ),
                    Expanded = Table.ExpandTableColumn(
                        Joined,
                        "_SecurityDim",
                        {"SecurityKey"},
                        {"SecurityKey"}
                    )
                in
                    Expanded
            else
                Table.AddColumn(ExpandAccountKey, "SecurityKey", each null, Int64.Type),

            // Join to get GroupKey
            WithGroupKey = if List.Contains(Table.ColumnNames(WithSecurityKey), "GroupName") then
                let
                    Joined = Table.NestedJoin(
                        WithSecurityKey,
                        {"GroupName"},
                        dimGroup,
                        {"GroupName"},
                        "_GroupDim",
                        JoinKind.LeftOuter
                    ),
                    Expanded = Table.ExpandTableColumn(
                        Joined,
                        "_GroupDim",
                        {"GroupKey"},
                        {"GroupKey"}
                    )
                in
                    Expanded
            else
                Table.AddColumn(WithSecurityKey, "GroupKey", each null, Int64.Type),

            // Add fact table surrogate key
            WithFactKey = Table.AddIndexColumn(WithGroupKey, "FactKey", 1, 1, Int64.Type),

            // Select fact table columns only
            FactColumns = {
                "FactKey", "DateKey", "AccountKey", "SecurityKey", "GroupKey",
                "PortfolioReturn", "BenchmarkReturn", "ActiveReturn",
                "PortfolioWeight", "BenchmarkWeight", "ActiveWeight",
                "AllocationEffect", "SelectionEffect", "InteractionEffect", "TotalEffect",
                "PortfolioContribution", "BenchmarkContribution", "ActiveContribution"
            },

            AvailableFactColumns = List.Intersect({
                FactColumns,
                Table.ColumnNames(WithFactKey)
            }),

            FactTable = Table.SelectColumns(WithFactKey, AvailableFactColumns)
        in
            FactTable,

    // Example execution
    AttributionData = GetAttributionData(),  // Your attribution data source
    DimDate = Dim_Date,                       // Reference to date dimension
    DimAccount = Dim_Account,                 // Reference to account dimension
    DimSecurity = Dim_Security,               // Reference to security dimension
    DimGroup = Dim_Group,                     // Reference to group dimension

    FactTable = BuildAttributionFactTable(
        AttributionData,
        DimDate,
        DimAccount,
        DimSecurity,
        DimGroup
    )
in
    FactTable
