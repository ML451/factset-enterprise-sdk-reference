// FactSet Formula API Power Query - Alternative data access via FactSet's Formula API.
// The Formula API lets you use FactSet's screening language (FQL) to pull any data item
// available in the FactSet terminal. Use this when you need metrics not covered by
// the dedicated content APIs.

let
    // Execute a cross-sectional formula request.
    // Returns data for multiple securities at a point in time.
    // Parameters:
    //   ids      - List of FactSet identifiers
    //   formulas - List of FQL formula strings (e.g., {"P_PRICE(0,,,,'USD')", "FF_SALES(ANN_R,0)"})
    //   token    - OAuth 2.0 Bearer token
    CrossSection = (ids as list, formulas as list, token as text) as table =>
        let
            apiBase = "https://api.factset.com/content/formula/v1/cross-sectional",
            requestBody = Json.FromValue([
                ids = ids,
                formulas = formulas
            ]),
            response = Web.Contents(apiBase, [
                Headers = [
                    #"Content-Type" = "application/json",
                    #"Accept" = "application/json",
                    #"Authorization" = "Bearer " & token
                ],
                Content = requestBody
            ]),
            parsed = Json.Document(response),
            data = parsed[data],
            toTable = Table.FromRecords(data)
        in
            toTable,

    // Execute a time-series formula request.
    // Returns data for a single security over time.
    // Parameters:
    //   ids      - List of FactSet identifiers
    //   formulas - List of FQL formula strings with date ranges
    //   token    - OAuth 2.0 Bearer token
    TimeSeries = (ids as list, formulas as list, token as text) as table =>
        let
            apiBase = "https://api.factset.com/content/formula/v1/time-series",
            requestBody = Json.FromValue([
                ids = ids,
                formulas = formulas
            ]),
            response = Web.Contents(apiBase, [
                Headers = [
                    #"Content-Type" = "application/json",
                    #"Accept" = "application/json",
                    #"Authorization" = "Bearer " & token
                ],
                Content = requestBody
            ]),
            parsed = Json.Document(response),
            data = parsed[data],
            toTable = Table.FromRecords(data)
        in
            toTable,

    Export = [
        CrossSection = CrossSection,
        TimeSeries = TimeSeries
    ]
in
    Export
