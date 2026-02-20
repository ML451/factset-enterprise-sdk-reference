let
    Source = FactSetAnalytics.Contents(),
    Analytics = Source{[Key="Analytics"]}[Data],
    PA = Analytics{[Key="PA"]}[Data],
    v3 = PA{[Key="v3"]}[Data],
    DateConverter = v3{[Key="FactSet.Analytics.PA.v3ConvertPADatesToAbsoluteFormat"]}[Data],
    MultiPortCalc = v3{[Key="v3RunPAMultiPortCalculationEC"]}[Data],
    Utilities = Source{[Key="Utilities"]}[Data],
    ThrottledIterator = Utilities{[Key="FactSet.Utilities.ThrottledFunctionIterator"]}[Data],

    // Define horizons: MTD, QTD, YTD, 1YR, 3YR, 5YR, ITD
    Horizons = Table.FromRecords({
        [Period = "MTD", RelativeStart = #"End Date"&"-MTD", RelativeEnd = #"End Date"],
        [Period = "QTD", RelativeStart = #"End Date"&"-QTD", RelativeEnd = #"End Date"],
        [Period = "YTD", RelativeStart = #"End Date"&"-YTD", RelativeEnd = #"End Date"],
        [Period = "1YR", RelativeStart = #"End Date"&"-1Y", RelativeEnd = #"End Date"],
        [Period = "3YR", RelativeStart = #"End Date"&"-3Y", RelativeEnd = #"End Date"],
        [Period = "5YR", RelativeStart = #"End Date"&"-5Y", RelativeEnd = #"End Date"],
        [Period = "ITD", RelativeStart = "INCEPTION", RelativeEnd = #"End Date"]
    }),

    // Convert dates to absolute format
    ConvertedHorizons = Table.AddColumn(
        Table.AddColumn(Horizons, "AbsoluteStart",
            each if [RelativeStart] = "INCEPTION" then "INCEPTION" else DateConverter([RelativeStart])),
        "AbsoluteEnd", each DateConverter([RelativeEnd])
    ),

    // Validation function
    ValidatePortfolios = (startDate, period) =>
        let
            ValidationResult = if period = "ITD" then
                [ValidIDs = Universe[ID], ValidCount = Table.RowCount(Universe)]
            else
                let
                    ValidPortfolios = Table.SelectRows(Universe,
                        each Date.From([InceptionDate]) <= startDate)
                in
                    [ValidIDs = ValidPortfolios[ID], ValidCount = Table.RowCount(ValidPortfolios)]
        in
            ValidationResult,

    // Add validation to horizons
    HorizonsWithValidation = Table.AddColumn(ConvertedHorizons, "Validation",
        each ValidatePortfolios([AbsoluteStart], [Period])
    ),

    ValidationExpanded = Table.ExpandRecordColumn(HorizonsWithValidation, "Validation",
        {"ValidIDs", "ValidCount"}
    ),

    ValidHorizons = Table.SelectRows(ValidationExpanded, each [ValidCount] > 0),
    HorizonsList = Table.ToRecords(ValidHorizons),

    // Define the PA calculation function that will be called by the throttled iterator
    PACalculationFunction = (horizon_record) =>
        if horizon_record[Period] = "ITD" then
            // For ITD, we need individual calls per portfolio
            let
                ITDFunction = (portfolioId) =>
                    let
                        Portfolio = Table.SelectRows(Universe, each [ID] = portfolioId){0},
                        InceptionDate = Date.From(Portfolio[InceptionDate])
                    in
                        MultiPortCalc(
                            null,
                            CTR_ID,
                            {portfolioId},
                            null,
                            null,
                            null,
                            InceptionDate,
                            horizon_record[AbsoluteEnd],
                            "Single",
                            null,
                            null,
                            null,
                            "Totals",
                            null,
                            null,
                            null
                        ),

                // Use throttled iterator for ITD portfolio calls
                ITDResults = ThrottledIterator(
                    ITDFunction,
                    horizon_record[ValidIDs],
                    3, // iterations_before_wait
                    2  // seconds_to_wait
                )
            in
                [Period = horizon_record[Period], Results = ITDResults]
        else
            // Standard batch call for other horizons
            let
                BatchResult = MultiPortCalc(
                    null,
                    CTR_ID,
                    horizon_record[ValidIDs],
                    null,
                    null,
                    null,
                    horizon_record[AbsoluteStart],
                    horizon_record[AbsoluteEnd],
                    "Single",
                    null,
                    null,
                    null,
                    "Totals",
                    null,
                    null,
                    null
                )
            in
                [Period = horizon_record[Period], Results = BatchResult],

    // Apply throttled iterator to all horizons
    FinalResults = ThrottledIterator(
        PACalculationFunction,
        HorizonsList,
        2, // Process 2 horizons before waiting
        5  // Wait 5 seconds between batches
    )

in
    FinalResults
