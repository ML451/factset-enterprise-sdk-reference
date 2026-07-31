// FactSet API Helper - Shared Power Query (M) functions for FactSet REST API interaction.
// Used by the FactSet Enterprise Analytics Power BI model.

let
    // Paginated API fetch: handles FactSet APIs that return paginated JSON responses.
    // Parameters:
    //   baseUrl   - Full endpoint URL (e.g. "https://api.factset.com/content/factset-prices/v1/prices")
    //   body      - Record to serialize as JSON request body
    //   token     - OAuth 2.0 Bearer token
    //   dataField - Name of the array field in the JSON response (usually "data")
    FetchPaginated = (baseUrl as text, body as record, token as text, optional dataField as text) as list =>
        let
            field = if dataField = null then "data" else dataField,
            response = Web.Contents(baseUrl, [
                Headers = [
                    #"Content-Type" = "application/json",
                    #"Accept" = "application/json",
                    #"Authorization" = "Bearer " & token
                ],
                Content = Json.FromValue(body),
                ManualStatusHandling = {400, 401, 403, 429, 500}
            ]),
            status = Value.Metadata(response)[Response.Status],
            parsed = if status = 200 then Json.Document(response) else error Error.Record("API Error", "HTTP " & Text.From(status)),
            data = Record.FieldOrDefault(parsed, field, {})
        in
            data,

    // Batch a large ID list into chunks to stay within API limits.
    // Parameters:
    //   ids      - Full list of identifiers
    //   batchSize - Max IDs per request (default 100)
    BatchIds = (ids as list, optional batchSize as number) as list =>
        let
            size = if batchSize = null then 100 else batchSize,
            count = List.Count(ids),
            batchCount = Number.RoundUp(count / size),
            batches = List.Transform(
                List.Numbers(0, batchCount),
                each List.Range(ids, _ * size, List.Min({size, count - _ * size}))
            )
        in
            batches,

    // Retry wrapper: retries a function up to N times with exponential backoff.
    // Handles transient 429 (rate limit) and 5xx errors.
    RetryWithBackoff = (fn as function, optional maxRetries as number) as any =>
        let
            retries = if maxRetries = null then 3 else maxRetries,
            attempt = (n as number) =>
                let
                    result = try fn()
                in
                    if result[HasError] then
                        if n < retries then
                            Function.InvokeAfter(() => @attempt(n + 1), #duration(0, 0, 0, Number.Power(2, n)))
                        else
                            error result[Error]
                    else
                        result[Value]
        in
            attempt(0),

    // Convert FactSet date parameters: handles relative dates (0 = today, -1 = yesterday)
    // and absolute YYYY-MM-DD strings.
    ResolveDateParam = (dateParam as text) as text =>
        let
            result = if dateParam = "0" then Date.ToText(Date.From(DateTime.LocalNow()), "yyyy-MM-dd")
                     else if Text.StartsWith(dateParam, "-") then
                        Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()), Number.From(dateParam)), "yyyy-MM-dd")
                     else dateParam
        in
            result,

    // Create a standardized error record for API failures.
    FormatAPIError = (endpoint as text, statusCode as number, message as text) as record =>
        [
            Endpoint = endpoint,
            StatusCode = statusCode,
            Message = message,
            Timestamp = DateTime.LocalNow()
        ],

    // FactSet API Helper module exports
    Export = [
        FetchPaginated = FetchPaginated,
        BatchIds = BatchIds,
        RetryWithBackoff = RetryWithBackoff,
        ResolveDateParam = ResolveDateParam,
        FormatAPIError = FormatAPIError
    ]
in
    Export
