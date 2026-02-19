// ============================================================================
// FACTSET STACH DATA TRANSFORMATIONS FOR POWER BI
// Optimal M Code for Multi-Portfolio Attribution Reports
// ============================================================================
// Version: 1.0.0
// Compatibility: Stach v2 (Column-Oriented) and Stach v3
// Use Case: PA3 Multi-Portfolio Attribution Analysis
// ============================================================================

// ============================================================================
// SECTION 1: CORE STACH PARSING FUNCTIONS
// ============================================================================

// ----------------------------------------------------------------------------
// Primary Stach Parser - Auto-detects format version
// ----------------------------------------------------------------------------
let
    ParseStachResponse = (response as record) as table =>
        let
            // Detect Stach version from response structure
            HasTables = Record.HasFields(response, "tables"),
            HasData = Record.HasFields(response, "data"),

            Result = if HasTables then
                // Stach v3 format (multiple tables)
                ParseStachV3(response)
            else if HasData and Record.HasFields(response[data], "columns") then
                // Stach v2 column-oriented format
                ParseStachV2ColumnOriented(response[data])
            else if HasData and Record.HasFields(response[data], "rows") then
                // Stach v2 row-oriented format
                ParseStachV2RowOriented(response[data])
            else
                // Fallback: try to extract data directly
                Table.FromRecords({response[data]})
        in
            Result
in
    ParseStachResponse,

// ----------------------------------------------------------------------------
// Stach v2 Column-Oriented Parser (Most Common for PA3)
// ----------------------------------------------------------------------------
let
    ParseStachV2ColumnOriented = (data as record) as table =>
        let
            // Extract column definitions
            Columns = data[columns],
            ColumnCount = List.Count(Columns),

            // Extract column metadata
            ColumnMeta = List.Transform(Columns, each [
                Name = _[name]? ?? _[id]? ?? "Column",
                Type = _[type]? ?? "STRING",
                Format = _[format]?,
                Description = _[description]?
            ]),

            ColumnNames = List.Transform(ColumnMeta, each _[Name]),
            ColumnTypes = List.Transform(ColumnMeta, each _[Type]),

            // Extract row data
            Rows = data[rows]? ?? data[data]?,

            // Handle different row formats
            RowData = if Rows = null then
                {}
            else if List.Count(Rows) > 0 and Record.HasFields(Rows{0}?, "values") then
                // Row objects with values array
                List.Transform(Rows, each _[values])
            else if List.Count(Rows) > 0 and Value.Is(Rows{0}, type list) then
                // Direct array of arrays
                Rows
            else
                // Record-based rows
                List.Transform(Rows, each Record.FieldValues(_)),

            // Build table
            DataTable = if List.Count(RowData) = 0 then
                #table(ColumnNames, {})
            else
                Table.FromRows(RowData, ColumnNames),

            // Apply type transformations
            TypedTable = ApplyStachTypes(DataTable, ColumnNames, ColumnTypes)
        in
            TypedTable
in
    ParseStachV2ColumnOriented,

// ----------------------------------------------------------------------------
// Stach v2 Row-Oriented Parser
// ----------------------------------------------------------------------------
let
    ParseStachV2RowOriented = (data as record) as table =>
        let
            Rows = data[rows],

            // Get column names from first row or headers
            Headers = if Record.HasFields(data, "headers") then
                data[headers]
            else if List.Count(Rows) > 0 then
                Record.FieldNames(Rows{0})
            else
                {},

            // Convert to table
            DataTable = Table.FromRecords(Rows, Headers, MissingField.UseNull)
        in
            DataTable
in
    ParseStachV2RowOriented,

// ----------------------------------------------------------------------------
// Stach v3 Multi-Table Parser
// ----------------------------------------------------------------------------
let
    ParseStachV3 = (response as record) as table =>
        let
            Tables = response[tables],

            // Parse each table
            ParsedTables = List.Transform(Tables, each
                let
                    TableDef = _[definition],
                    TableData = _[data],

                    Columns = TableDef[columns],
                    ColumnNames = List.Transform(Columns, each _[name]? ?? _[id]),
                    ColumnTypes = List.Transform(Columns, each _[type]? ?? "STRING"),

                    Rows = TableData[rows],
                    RowValues = List.Transform(Rows, each _[values]? ?? _),

                    DataTable = Table.FromRows(RowValues, ColumnNames),
                    TypedTable = ApplyStachTypes(DataTable, ColumnNames, ColumnTypes)
                in
                    TypedTable
            ),

            // Combine tables (for multi-unit results)
            CombinedTable = Table.Combine(ParsedTables)
        in
            CombinedTable
in
    ParseStachV3,

// ----------------------------------------------------------------------------
// Type Mapping and Application
// ----------------------------------------------------------------------------
let
    ApplyStachTypes = (table as table, columnNames as list, stachTypes as list) as table =>
        let
            // Stach type to M type mapping
            TypeMap = [
                #"STRING" = type text,
                #"REAL" = type number,
                #"DOUBLE" = type number,
                #"FLOAT" = type number,
                #"INT32" = Int32.Type,
                #"INT64" = Int64.Type,
                #"BOOL" = type logical,
                #"BOOLEAN" = type logical,
                #"DATETIME" = type datetime,
                #"DATE" = type date,
                #"DURATION" = type duration,
                #"TIMESTAMP" = type datetimezone
            ],

            // Build transformation list
            Transforms = List.Transform(
                List.Positions(columnNames),
                each {
                    columnNames{_},
                    Record.FieldOrDefault(TypeMap, Text.Upper(stachTypes{_}), type any)
                }
            ),

            // Apply transformations with error handling
            Result = try Table.TransformColumnTypes(table, Transforms)
                     otherwise table
        in
            Result
in
    ApplyStachTypes,


// ============================================================================
// SECTION 2: MULTI-PORTFOLIO ATTRIBUTION PROCESSING
// ============================================================================

// ----------------------------------------------------------------------------
// Process Multiple Portfolio Calculations
// ----------------------------------------------------------------------------
let
    ProcessMultiPortfolioResults = (
        calculationResults as list,
        portfolioMetadata as table
    ) as table =>
        let
            // Parse each portfolio's results
            ParsedResults = List.Transform(
                List.Positions(calculationResults),
                each
                    let
                        Result = calculationResults{_},
                        PortfolioIndex = _,

                        // Parse Stach data
                        ParsedTable = ParseStachResponse(Result),

                        // Add portfolio identifier
                        WithPortfolioKey = Table.AddColumn(
                            ParsedTable,
                            "_PortfolioIndex",
                            each PortfolioIndex,
                            Int64.Type
                        )
                    in
                        WithPortfolioKey
            ),

            // Combine all portfolios
            CombinedResults = Table.Combine(ParsedResults),

            // Join with portfolio metadata
            EnrichedResults = Table.NestedJoin(
                CombinedResults,
                {"_PortfolioIndex"},
                Table.AddIndexColumn(portfolioMetadata, "_PortfolioIndex", 0, 1),
                {"_PortfolioIndex"},
                "_PortfolioMeta",
                JoinKind.LeftOuter
            ),

            // Expand portfolio metadata
            ExpandedResults = Table.ExpandTableColumn(
                EnrichedResults,
                "_PortfolioMeta",
                {"PortfolioId", "PortfolioName", "BenchmarkId", "BenchmarkName"},
                {"PortfolioId", "PortfolioName", "BenchmarkId", "BenchmarkName"}
            ),

            // Remove temporary index
            CleanedResults = Table.RemoveColumns(ExpandedResults, {"_PortfolioIndex"})
        in
            CleanedResults
in
    ProcessMultiPortfolioResults,

// ----------------------------------------------------------------------------
// Standardize Attribution Column Names
// ----------------------------------------------------------------------------
let
    StandardizeAttributionColumns = (table as table) as table =>
        let
            // Common PA3 column name mappings
            ColumnMappings = [
                // Returns
                #"Port. Return" = "PortfolioReturn",
                #"Port. Total Return" = "PortfolioReturn",
                #"Portfolio Return" = "PortfolioReturn",
                #"Bench. Return" = "BenchmarkReturn",
                #"Bench. Total Return" = "BenchmarkReturn",
                #"Benchmark Return" = "BenchmarkReturn",
                #"Active Return" = "ActiveReturn",
                #"Excess Return" = "ActiveReturn",

                // Attribution Effects
                #"Allocation" = "AllocationEffect",
                #"Allocation Effect" = "AllocationEffect",
                #"Selection" = "SelectionEffect",
                #"Selection Effect" = "SelectionEffect",
                #"Interaction" = "InteractionEffect",
                #"Interaction Effect" = "InteractionEffect",
                #"Total Effect" = "TotalEffect",
                #"Total Attribution" = "TotalEffect",
                #"Currency Effect" = "CurrencyEffect",
                #"Currency" = "CurrencyEffect",

                // Weights
                #"Port. Weight" = "PortfolioWeight",
                #"Port. Ending Weight" = "PortfolioWeight",
                #"Portfolio Weight" = "PortfolioWeight",
                #"Bench. Weight" = "BenchmarkWeight",
                #"Bench. Ending Weight" = "BenchmarkWeight",
                #"Benchmark Weight" = "BenchmarkWeight",
                #"Active Weight" = "ActiveWeight",
                #"Overweight" = "ActiveWeight",

                // Contributions
                #"Port. Contribution" = "PortfolioContribution",
                #"Portfolio Contribution" = "PortfolioContribution",
                #"Bench. Contribution" = "BenchmarkContribution",
                #"Benchmark Contribution" = "BenchmarkContribution",
                #"Active Contribution" = "ActiveContribution",

                // Identifiers
                #"Security Name" = "SecurityName",
                #"Security" = "SecurityName",
                #"Name" = "SecurityName",
                #"Ticker" = "Ticker",
                #"Symbol" = "Ticker",
                #"CUSIP" = "CUSIP",
                #"ISIN" = "ISIN",
                #"SEDOL" = "SEDOL",
                #"Group" = "GroupName",
                #"Grouping" = "GroupName",
                #"Sector" = "Sector",
                #"Industry" = "Industry",

                // Dates
                #"Date" = "Date",
                #"Period" = "Date",
                #"Period End Date" = "Date",
                #"Start Date" = "StartDate",
                #"End Date" = "EndDate"
            ],

            // Get current column names
            CurrentColumns = Table.ColumnNames(table),

            // Build rename pairs for columns that exist
            RenamePairs = List.Transform(
                CurrentColumns,
                each {_, Record.FieldOrDefault(ColumnMappings, _, _)}
            ),

            // Filter to only rename columns that have mappings
            ActualRenames = List.Select(
                RenamePairs,
                each _{0} <> _{1}
            ),

            // Apply renames
            RenamedTable = if List.Count(ActualRenames) > 0 then
                Table.RenameColumns(table, ActualRenames, MissingField.Ignore)
            else
                table
        in
            RenamedTable
in
    StandardizeAttributionColumns,

// ----------------------------------------------------------------------------
// Calculate Derived Attribution Metrics
// ----------------------------------------------------------------------------
let
    AddDerivedAttributionMetrics = (table as table) as table =>
        let
            Columns = Table.ColumnNames(table),

            // Add Total Effect if components exist but total doesn't
            WithTotalEffect = if List.Contains(Columns, "AllocationEffect")
                               and List.Contains(Columns, "SelectionEffect")
                               and not List.Contains(Columns, "TotalEffect") then
                Table.AddColumn(
                    table,
                    "TotalEffect",
                    each [AllocationEffect] + [SelectionEffect] +
                         (if Record.HasFields(_, "InteractionEffect") then [InteractionEffect] else 0),
                    type number
                )
            else
                table,

            // Add Active Return if portfolio and benchmark returns exist
            WithActiveReturn = if List.Contains(Table.ColumnNames(WithTotalEffect), "PortfolioReturn")
                                and List.Contains(Table.ColumnNames(WithTotalEffect), "BenchmarkReturn")
                                and not List.Contains(Table.ColumnNames(WithTotalEffect), "ActiveReturn") then
                Table.AddColumn(
                    WithTotalEffect,
                    "ActiveReturn",
                    each [PortfolioReturn] - [BenchmarkReturn],
                    type number
                )
            else
                WithTotalEffect,

            // Add Active Weight
            WithActiveWeight = if List.Contains(Table.ColumnNames(WithActiveReturn), "PortfolioWeight")
                                and List.Contains(Table.ColumnNames(WithActiveReturn), "BenchmarkWeight")
                                and not List.Contains(Table.ColumnNames(WithActiveReturn), "ActiveWeight") then
                Table.AddColumn(
                    WithActiveReturn,
                    "ActiveWeight",
                    each [PortfolioWeight] - [BenchmarkWeight],
                    type number
                )
            else
                WithActiveReturn,

            // Add Active Contribution
            WithActiveContrib = if List.Contains(Table.ColumnNames(WithActiveWeight), "PortfolioContribution")
                                 and List.Contains(Table.ColumnNames(WithActiveWeight), "BenchmarkContribution")
                                 and not List.Contains(Table.ColumnNames(WithActiveWeight), "ActiveContribution") then
                Table.AddColumn(
                    WithActiveWeight,
                    "ActiveContribution",
                    each [PortfolioContribution] - [BenchmarkContribution],
                    type number
                )
            else
                WithActiveWeight
        in
            WithActiveContrib
in
    AddDerivedAttributionMetrics,


// ============================================================================
// SECTION 3: HIERARCHICAL GROUP PROCESSING
// ============================================================================

// ----------------------------------------------------------------------------
// Expand Nested Group Hierarchies
// ----------------------------------------------------------------------------
let
    ExpandGroupHierarchy = (table as table, groupColumn as text) as table =>
        let
            // Check if column contains hierarchical data (e.g., "Technology|Software|Cloud")
            SampleValue = try Table.Column(table, groupColumn){0} otherwise null,

            IsHierarchical = SampleValue <> null and Text.Contains(SampleValue, "|"),

            Result = if IsHierarchical then
                let
                    // Split hierarchy into levels
                    WithLevels = Table.AddColumn(
                        table,
                        "_GroupLevels",
                        each Text.Split(Record.Field(_, groupColumn), "|")
                    ),

                    // Add individual level columns
                    MaxLevels = List.Max(
                        List.Transform(
                            Table.Column(WithLevels, "_GroupLevels"),
                            each List.Count(_)
                        )
                    ),

                    AddLevelColumns = List.Accumulate(
                        List.Numbers(1, MaxLevels),
                        WithLevels,
                        (state, level) =>
                            Table.AddColumn(
                                state,
                                "GroupLevel" & Text.From(level),
                                each try _[_GroupLevels]{level - 1} otherwise null,
                                type text
                            )
                    ),

                    // Add leaf group flag
                    WithLeafFlag = Table.AddColumn(
                        AddLevelColumns,
                        "IsLeafGroup",
                        each List.Count(_[_GroupLevels]) = MaxLevels,
                        type logical
                    ),

                    // Remove temp column
                    Cleaned = Table.RemoveColumns(WithLeafFlag, {"_GroupLevels"})
                in
                    Cleaned
            else
                // Single level - just rename
                Table.RenameColumns(table, {{groupColumn, "GroupLevel1"}}, MissingField.Ignore)
        in
            Result
in
    ExpandGroupHierarchy,

// ----------------------------------------------------------------------------
// Aggregate to Group Level
// ----------------------------------------------------------------------------
let
    AggregateToGroupLevel = (
        table as table,
        groupColumns as list,
        aggregateColumns as list
    ) as table =>
        let
            // Build aggregation specifications
            AggSpecs = List.Transform(
                aggregateColumns,
                each {_, List.Sum, _}
            ),

            // Perform grouping
            Grouped = Table.Group(
                table,
                groupColumns,
                AggSpecs
            )
        in
            Grouped
in
    AggregateToGroupLevel,


// ============================================================================
// SECTION 4: DATE AND PERIOD HANDLING
// ============================================================================

// ----------------------------------------------------------------------------
// Parse FactSet Date Formats
// ----------------------------------------------------------------------------
let
    ParseFactSetDate = (dateValue as any) as date =>
        let
            Result = if dateValue = null then
                null
            else if Value.Is(dateValue, type date) then
                dateValue
            else if Value.Is(dateValue, type datetime) then
                DateTime.Date(dateValue)
            else if Value.Is(dateValue, type text) then
                let
                    // Try YYYYMMDD format
                    TryYYYYMMDD = try Date.FromText(
                        Text.Start(dateValue, 4) & "-" &
                        Text.Middle(dateValue, 4, 2) & "-" &
                        Text.Middle(dateValue, 6, 2)
                    ),

                    // Try standard formats
                    TryStandard = try Date.FromText(dateValue),

                    // Try MM/DD/YYYY
                    TryUSFormat = try Date.FromText(dateValue, [Format="MM/dd/yyyy"])
                in
                    if TryYYYYMMDD[HasError] = false then TryYYYYMMDD[Value]
                    else if TryStandard[HasError] = false then TryStandard[Value]
                    else if TryUSFormat[HasError] = false then TryUSFormat[Value]
                    else null
            else if Value.Is(dateValue, type number) then
                // Excel serial date
                Date.AddDays(#date(1899, 12, 30), dateValue)
            else
                null
        in
            Result
in
    ParseFactSetDate,

// ----------------------------------------------------------------------------
// Add Date Key Column (for joining to Dim_Date)
// ----------------------------------------------------------------------------
let
    AddDateKey = (table as table, dateColumn as text) as table =>
        let
            WithParsedDate = Table.TransformColumns(
                table,
                {{dateColumn, ParseFactSetDate, type date}}
            ),

            WithDateKey = Table.AddColumn(
                WithParsedDate,
                "DateKey",
                each if Record.Field(_, dateColumn) <> null then
                    Number.From(Date.ToText(Record.Field(_, dateColumn), "yyyyMMdd"))
                else
                    null,
                Int64.Type
            )
        in
            WithDateKey
in
    AddDateKey,

// ----------------------------------------------------------------------------
// Expand Time Series for Multiple Periods
// ----------------------------------------------------------------------------
let
    ExpandTimeSeries = (
        table as table,
        dateColumn as text,
        valueColumns as list
    ) as table =>
        let
            // Unpivot value columns for time series analysis
            OtherColumns = List.RemoveItems(Table.ColumnNames(table), valueColumns),

            Unpivoted = Table.UnpivotOtherColumns(
                table,
                OtherColumns,
                "Metric",
                "Value"
            )
        in
            Unpivoted
in
    ExpandTimeSeries,


// ============================================================================
// SECTION 5: PERFORMANCE OPTIMIZED BATCH PROCESSING
// ============================================================================

// ----------------------------------------------------------------------------
// Buffered Batch Processing for Large Datasets
// ----------------------------------------------------------------------------
let
    ProcessInBatches = (
        items as list,
        batchSize as number,
        processFunction as function
    ) as list =>
        let
            ItemCount = List.Count(items),
            BatchCount = Number.RoundUp(ItemCount / batchSize),

            Batches = List.Transform(
                List.Numbers(0, BatchCount),
                each
                    let
                        StartIndex = _ * batchSize,
                        EndIndex = Number.Min(StartIndex + batchSize, ItemCount),
                        BatchItems = List.Range(items, StartIndex, EndIndex - StartIndex),

                        // Process batch
                        ProcessedBatch = processFunction(BatchItems),

                        // Buffer to free memory
                        BufferedBatch = Table.Buffer(ProcessedBatch)
                    in
                        BufferedBatch
            ),

            // Combine all batches
            Combined = Table.Combine(Batches)
        in
            {Combined}
in
    ProcessInBatches,

// ----------------------------------------------------------------------------
// Memory-Efficient Column Selection
// ----------------------------------------------------------------------------
let
    SelectAttributionColumns = (table as table) as table =>
        let
            // Define essential attribution columns
            EssentialColumns = {
                // Identifiers
                "PortfolioId", "PortfolioName", "BenchmarkId", "BenchmarkName",
                "SecurityName", "Ticker", "CUSIP", "ISIN",
                "GroupName", "Sector", "Industry",
                "Date", "DateKey",

                // Core Metrics
                "PortfolioReturn", "BenchmarkReturn", "ActiveReturn",
                "PortfolioWeight", "BenchmarkWeight", "ActiveWeight",
                "AllocationEffect", "SelectionEffect", "InteractionEffect", "TotalEffect",
                "PortfolioContribution", "BenchmarkContribution", "ActiveContribution"
            },

            // Get columns that exist in table
            AvailableColumns = Table.ColumnNames(table),
            ColumnsToKeep = List.Intersect({EssentialColumns, AvailableColumns}),

            // Select only needed columns
            SelectedTable = Table.SelectColumns(table, ColumnsToKeep, MissingField.Ignore)
        in
            SelectedTable
in
    SelectAttributionColumns,


// ============================================================================
// SECTION 6: COMPLETE TRANSFORMATION PIPELINE
// ============================================================================

// ----------------------------------------------------------------------------
// Full Attribution Report Pipeline
// ----------------------------------------------------------------------------
let
    TransformAttributionReport = (
        stachResponse as record,
        optional portfolioId as text,
        optional portfolioName as text,
        optional benchmarkId as text,
        optional benchmarkName as text
    ) as table =>
        let
            // Step 1: Parse Stach format
            ParsedData = ParseStachResponse(stachResponse),

            // Step 2: Standardize column names
            StandardizedData = StandardizeAttributionColumns(ParsedData),

            // Step 3: Add portfolio identifiers if provided
            WithPortfolio = if portfolioId <> null then
                let
                    WithId = Table.AddColumn(StandardizedData, "PortfolioId", each portfolioId, type text),
                    WithName = Table.AddColumn(WithId, "PortfolioName", each portfolioName ?? portfolioId, type text)
                in
                    WithName
            else
                StandardizedData,

            // Step 4: Add benchmark identifiers if provided
            WithBenchmark = if benchmarkId <> null then
                let
                    WithId = Table.AddColumn(WithPortfolio, "BenchmarkId", each benchmarkId, type text),
                    WithName = Table.AddColumn(WithId, "BenchmarkName", each benchmarkName ?? benchmarkId, type text)
                in
                    WithName
            else
                WithPortfolio,

            // Step 5: Calculate derived metrics
            WithDerived = AddDerivedAttributionMetrics(WithBenchmark),

            // Step 6: Add date key if date column exists
            WithDateKey = if List.Contains(Table.ColumnNames(WithDerived), "Date") then
                AddDateKey(WithDerived, "Date")
            else
                WithDerived,

            // Step 7: Select essential columns for efficiency
            OptimizedData = SelectAttributionColumns(WithDateKey),

            // Step 8: Buffer final result
            BufferedResult = Table.Buffer(OptimizedData)
        in
            BufferedResult
in
    TransformAttributionReport,

// ----------------------------------------------------------------------------
// Multi-Portfolio Attribution Pipeline
// ----------------------------------------------------------------------------
let
    TransformMultiPortfolioAttribution = (
        calculationResults as list,
        portfolioConfigs as list  // List of [PortfolioId, PortfolioName, BenchmarkId, BenchmarkName]
    ) as table =>
        let
            // Process each portfolio
            ProcessedPortfolios = List.Transform(
                List.Positions(calculationResults),
                each
                    let
                        Result = calculationResults{_},
                        Config = portfolioConfigs{_},

                        Transformed = TransformAttributionReport(
                            Result,
                            Config[PortfolioId]?,
                            Config[PortfolioName]?,
                            Config[BenchmarkId]?,
                            Config[BenchmarkName]?
                        )
                    in
                        Transformed
            ),

            // Combine all portfolios
            CombinedData = Table.Combine(ProcessedPortfolios),

            // Add row index for debugging/tracing
            WithRowId = Table.AddIndexColumn(CombinedData, "RowId", 1, 1, Int64.Type),

            // Final buffer
            FinalResult = Table.Buffer(WithRowId)
        in
            FinalResult
in
    TransformMultiPortfolioAttribution,


// ============================================================================
// SECTION 7: VALIDATION AND ERROR HANDLING
// ============================================================================

// ----------------------------------------------------------------------------
// Validate Attribution Data Quality
// ----------------------------------------------------------------------------
let
    ValidateAttributionData = (table as table) as record =>
        let
            RowCount = Table.RowCount(table),
            Columns = Table.ColumnNames(table),

            // Check for required columns
            RequiredColumns = {"PortfolioReturn", "BenchmarkReturn"},
            MissingRequired = List.RemoveItems(RequiredColumns, Columns),
            HasRequiredColumns = List.IsEmpty(MissingRequired),

            // Check for null values in key columns
            NullChecks = List.Transform(
                List.Intersect({RequiredColumns, Columns}),
                each [
                    Column = _,
                    NullCount = List.Count(List.Select(Table.Column(table, _), each _ = null)),
                    NullPercent = if RowCount > 0 then NullCount / RowCount * 100 else 0
                ]
            ),

            // Check attribution balancing (Total Effect should equal sum of components)
            AttributionBalance = if List.ContainsAll(Columns, {"AllocationEffect", "SelectionEffect", "TotalEffect"}) then
                let
                    Variance = Table.AddColumn(
                        table,
                        "_Variance",
                        each Number.Abs(
                            [TotalEffect] - [AllocationEffect] - [SelectionEffect] -
                            (if List.Contains(Columns, "InteractionEffect") then [InteractionEffect] else 0)
                        )
                    ),
                    MaxVariance = List.Max(Table.Column(Variance, "_Variance")),
                    IsBalanced = MaxVariance < 0.0001  // Tolerance for floating point
                in
                    [IsBalanced = IsBalanced, MaxVariance = MaxVariance]
            else
                [IsBalanced = null, MaxVariance = null],

            // Summary
            ValidationResult = [
                IsValid = HasRequiredColumns and (AttributionBalance[IsBalanced] ?? true),
                RowCount = RowCount,
                ColumnCount = List.Count(Columns),
                MissingRequiredColumns = MissingRequired,
                NullAnalysis = NullChecks,
                AttributionBalance = AttributionBalance,
                Warnings = List.RemoveNulls({
                    if not HasRequiredColumns then "Missing required columns: " & Text.Combine(MissingRequired, ", ") else null,
                    if AttributionBalance[IsBalanced] = false then "Attribution effects do not balance. Max variance: " & Text.From(AttributionBalance[MaxVariance]) else null
                })
            ]
        in
            ValidationResult
in
    ValidateAttributionData,

// ----------------------------------------------------------------------------
// Safe Transformation with Error Logging
// ----------------------------------------------------------------------------
let
    SafeTransform = (
        transformFunction as function,
        input as any,
        errorDefault as any
    ) as any =>
        let
            Result = try transformFunction(input),

            Output = if Result[HasError] then
                let
                    ErrorLog = [
                        Timestamp = DateTime.LocalNow(),
                        ErrorReason = Result[Error][Reason],
                        ErrorMessage = Result[Error][Message],
                        ErrorDetail = Result[Error][Detail]?
                    ],
                    // In production, you would log this
                    _ = ErrorLog
                in
                    errorDefault
            else
                Result[Value]
        in
            Output
in
    SafeTransform,


// ============================================================================
// SECTION 8: EXPORT FUNCTIONS (Share These in Power BI)
// ============================================================================

// Main shared functions to expose in Power BI
[
    // Core parsing
    ParseStachResponse = ParseStachResponse,
    ParseStachV2ColumnOriented = ParseStachV2ColumnOriented,
    ParseStachV3 = ParseStachV3,

    // Attribution processing
    StandardizeAttributionColumns = StandardizeAttributionColumns,
    AddDerivedAttributionMetrics = AddDerivedAttributionMetrics,
    TransformAttributionReport = TransformAttributionReport,
    TransformMultiPortfolioAttribution = TransformMultiPortfolioAttribution,

    // Group handling
    ExpandGroupHierarchy = ExpandGroupHierarchy,
    AggregateToGroupLevel = AggregateToGroupLevel,

    // Date handling
    ParseFactSetDate = ParseFactSetDate,
    AddDateKey = AddDateKey,

    // Validation
    ValidateAttributionData = ValidateAttributionData,
    SafeTransform = SafeTransform,

    // Utilities
    ApplyStachTypes = ApplyStachTypes,
    SelectAttributionColumns = SelectAttributionColumns,
    ProcessInBatches = ProcessInBatches
]
