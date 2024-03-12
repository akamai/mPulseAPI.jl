###################################################
#
# Copyright Akamai, Inc.
# Distributed under the terms of the MIT license
#
# File: QueryAPI.jl
#
# Functions to communicate with the mPulse REST Query API
# This file MUST be `include()`d from `mPulseAPI.jl`
#
###################################################

using DataFrames, JSON, Format

const nullval = missing

const query_types = [
        "summary",
        "histogram",
        "sessions-per-page-load-time",
        "metric-per-page-load-time",
        "by-minute",
        "geography",
        "page-groups",
        "browsers",
        "bandwidth",
        "ab-tests",
        "timers-metrics",
        "metrics-by-dimension"
    ]


"""
Get API results from the mPulse [Query API](http://docs.soasta.com/query-api/)

This method is a generic catch-all that queries the mPulse API and returns results as a Julia data structure matching the JSON structure of the specified API call

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

`query_type::AbstractString`
:    The specific API query to make.  Must be one of the following:

$(mapfoldl(x -> "   * $x\n", *, mPulseAPI.query_types))

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

### Throws
`ArgumentError`
:   If the `query_type` is not recognized

$(mPulseAPI.readdocs("APIResults-exceptions"))

### Returns
`{Any}` A Julia representation of the JSON returned by the API call. Convenience wrappers in this library may return more appropriate data structures.
"""
function getAPIResults(token::AbstractString, appKey::AbstractString, query_type::AbstractString; filters::Dict=Dict())
    global verbose

    if query_type ∉ query_types
        throw(ArgumentError("Unrecognized query_type $(query_type)"))
    end

    url = string(mPulseEndpoint, appKey, "/", query_type)

    query = Dict{AbstractString, Union{AbstractString, Array}}(
        "date-comparator" => "Last24Hours",
        "format" => "json",
        "series-format" => "json"
    )

    for (k, v) in filters
        if haskey(query, k) && v == ""
            delete!(query, k)
        elseif k ∈ ["date-start", "date-end"] && isa(v, DateTime)
            query[k] = string(v, "Z")
        elseif k == "date" && isa(v, DateTime) || isa(v, Date)
            query[k] = string(Date(v))
        elseif isa(v, AbstractArray)
            query[k] = v
        else
            query[k] = string(v)
        end
    end

    headers = Dict(
        "Authentication" => token,
        "User-Agent" => "mPulseAPI-julia/1.0.0",
        "Accept" => "application/json"
    )

    if verbose
        println("GET $url")
        println(headers)
        println(query)
    end

    resp = HTTP.get(url, headers, query=query, status_exception=false)

    local object = Dict()

    json = String(resp.body)

    if resp.status == 401
        throw(mPulseAPIAuthException(resp))
    elseif resp.status != 200
        object = JSON.parse(json)

        if haskey(object, "rs_fault")
            object = object["rs_fault"]
        end

        if haskey(object, "code")
            if object["code"] == "ResultsService.InvalidToken"
                throw(mPulseAPIAuthException(resp))
            elseif object["code"] == "MPulseAPIException.InvalidParameter"
                # Extract the parameter name
                parameter = lowercase(replace(replace(object["message"], r"^.*?: " => ""), r" .*" => ""))

                # Extract the parameter value
                value = replace(object["message"], r".*: *" => "")

                throw(mPulseAPIRequestException(object["message"], object["code"], parameter, value, resp))
            end
        end

        if resp.status == 500
            throw(mPulseAPIBugException(resp))
        else
            throw(mPulseAPIException("Error fetching $(query_type)", resp))
        end
    end

    # Remove double quotes around negative numbers (Bug 110740)
    json = replace(json, r"\"(-\d+)\"" => s"\1")

    try
        object = JSON.parse(json)
    catch ex
        # JSON Parsing error, we'll try cleaning it up, but if that fails, throw an mPulseAPIException so that the caller can inspect `resp`

        try
            # Enclose all string keys in double quotes
            # We use a positive lookbehind assertion to identify keys by being strings preceeded by { [ or ,
            json = replace(json, r"(?<=[{\[,])( *)(\w+):" => s"\"\2\":")
            object = JSON.parse(json)
        catch
            # We'll throw the original exception if cleaning did not work
            if isdefined(ex, :msg)
                throw(mPulseAPIException(ex.msg, resp))
            else
                throw(mPulseAPIException(string(ex), resp))
            end
        end
    end

    for k in keys(object)
        try
            object[k] = fixJSONDataType(object[k])
        catch;
        end
    end

    return object
end




"""
Calls the `summary` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions"))

### Returns
`{Dict}` A Julia `Dict` with the following string keys:

`n::Int`
:   The number of beacons with data about the requested timer

`median::Int`
:   The median of the requested timer in milliseconds

`p95::Int`
:   The 95th percentile value of the requested timer in milliseconds

`p98::Int`
:   The 98th percentile value of the requested timer in milliseconds

`moe::Float`
:   The 95% confidence interval margin of error on the arithmetic mean of the requested timer in milliseconds


### Examples

```julia
julia> summary = mPulseAPI.getSummaryTimers(token, appKey)

Dict{Any,Any} with 5 entries:
  "n"      => 356317
  "median" => 3094
  "p95"    => 19700
  "p98"    => 40678
  "moe"    => 13.93
```
"""
function getSummaryTimers(token::AbstractString, appKey::AbstractString; filters::Dict=Dict())
    return getAPIResults(token, appKey, "summary", filters=filters)
end




"""
Calls the `page-groups` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

$(mPulseAPI.readdocs("friendly-names", ["Page Group", "page_group"]))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions"))

$(mPulseAPI.readdocs("CleanSeriesSeries-exceptions", [""]))

### Returns
$(mPulseAPI.readdocs("friendly-names-df", ["page_group", "PageGroup", "www", "blog", "Search", "SKU", "PLU", "(No Page Group)", "Checkout"]))
"""
function getPageGroupTimers(token::AbstractString, appKey::AbstractString; filters::Dict=Dict(), friendly_names::Bool=false)
    results = getAPIResults(token, appKey, "page-groups", filters=filters)

    if length(results) == 0
        return DataFrame()
    end

    df = resultsToDataFrame(results["columnNames"], :primary, results["data"])

    if !friendly_names
        rename!(df, [:page_group, :t_done_median, :t_done_moe, :t_done_count, :t_done_total_pc])
    end

    return df
end




"""
Calls the `browsers` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

$(mPulseAPI.readdocs("friendly-names", ["User Agent", "user_agent"]))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions"))

$(mPulseAPI.readdocs("CleanSeriesSeries-exceptions", [""]))

### Returns
$(mPulseAPI.readdocs("friendly-names-df", ["user_agent", "Browser", "Chrome/50", "Safari/9", "Mobile Safari/9", "Firefox/46", "Chrome/49", "IE/11", "Edge/13"]))
"""
function getBrowserTimers(token::AbstractString, appKey::AbstractString; filters::Dict=Dict(), friendly_names::Bool=false)
    results = getAPIResults(token, appKey, "browsers", filters=filters)

    if length(results) == 0
        return DataFrame()
    end

    df = resultsToDataFrame(results["columnNames"], :primary, results["data"])

    if !friendly_names
        rename!(df, ["user_agent", "t_done_median", "t_done_moe", "t_done_count", "t_done_total_pc"])
    end

    return df
end




"""
Calls the `ab-tests` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

$(mPulseAPI.readdocs("friendly-names", ["Test Name", "test_name"]))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions"))

$(mPulseAPI.readdocs("CleanSeriesSeries-exceptions", [""]))

### Returns
$(mPulseAPI.readdocs("friendly-names-df", ["test_name", "ABTest", "(No Value)", "Test-A", "Test-B", "BlueHead", "Campaign-XXX", "Old-Site", "Slow-SRP"]))
"""
function getABTestTimers(token::AbstractString, appKey::AbstractString; filters::Dict=Dict(), friendly_names::Bool=false)
    results = getAPIResults(token, appKey, "ab-tests", filters=filters)

    if length(results) == 0
        return DataFrame()
    end

    df = resultsToDataFrame(results["columnNames"], :primary, results["data"])

    if !friendly_names
        rename!(df, ["test_name", "t_done_median", "t_done_moe", "t_done_count", "t_done_total_pc"])
    end

    return df
end




"""
Calls the `geography` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

$(mPulseAPI.readdocs("friendly-names", ["Country", "country"]))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions"))

$(mPulseAPI.readdocs("CleanSeriesSeries-exceptions", [""]))

### Returns
$(mPulseAPI.readdocs("friendly-names-df", ["country", "Country", "US", "CA", "MX", "PH", "AU", "KR", "PE"]))
"""
function getGeoTimers(token::AbstractString, appKey::AbstractString; filters::Dict=Dict(), friendly_names::Bool=false)
    results = getAPIResults(token, appKey, "geography", filters=filters)

    if length(results) == 0
        return DataFrame()
    end

    df = resultsToDataFrame( Symbol[:country, :timerMedian, :timerMOE, :timerN], :primary, results["data"] )

    df[!, :t_done_total_pc] = df[!, :timerN] * 100 / sum(df[!, :timerN])

    if friendly_names
        rename!(df, ["Country", "Median Time (ms)", "MoE (ms)", "Measurements", "% of total"])
    else
        rename!(df, ["country", "t_done_median", "t_done_moe", "t_done_count", "t_done_total_pc"])
    end

    return df
end




"""
Calls the `metrics-by-dimension` endpoint of the mPulse REST API with the passed in dimension name and filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

`dimension::AbstractString`
:    The dimension to split metrics by.  The response contains one row for each value of this dimension.  The following dimensions are supported:

* page_group
* browser
* country
* bw_block
* ab_test

See [https://techdocs.akamai.com/mpulse/reference/get-metrics-by-dimension](https://techdocs.akamai.com/mpulse/reference/get-metrics-by-dimension)
for an up-to-date list.

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions"))

$(mPulseAPI.readdocs("CleanSeriesSeries-exceptions", [""]))

### Returns
`{DataFrame}` A Julia `DataFrame` with the following columns: `:<dimension>`, `:<CustomMetric Name>`...

```julia
julia> mPulseAPI.getMetricsByDimension(token, appKey, "browser")
243x4 DataFrames.DataFrame
| Row | browser                          | Conversion | OrderTotal | ServerDown  |
|-----|----------------------------------|------------|------------|-------------|
| 1   | "Mobile Safari/9"                | 1.381      | 1.62854e7  | 0.000994956 |
| 2   | "Chrome/50"                      | 1.98411    | 3.13401e7  | 0.0050615   |
| 3   | "Safari/9"                       | 3.08288    | 2.10698e7  | 0.00561545  |
| 4   | "Firefox/46"                     | 1.90974    | 8569362    | 0.00462406  |
| 5   | "Mobile Safari/8"                | 2.38545    | 2295848    | 0.0         |
| 6   | "Chrome/49"                      | 2.22828    | 4394331    | 0.0         |
```
"""
function getMetricsByDimension(token::AbstractString, appKey::AbstractString, dimension::AbstractString; filters::Dict=Dict())
    filters["dimension"] = dimension

    results = getAPIResults(token, appKey, "metrics-by-dimension", filters=filters)

    if length(results) == 0
        results = Dict("columnNames" => [], "data" => [])
    end

    if results["data"] == nothing
        results["data"] = []
    end

    if length(results["columnNames"]) == 0 || results["columnNames"][2] == nothing || startswith(results["columnNames"][2], "CustomMetric")
        # The API returned bad columns or no results.  Let's try our best to return a consistent albeit empty DataFrame

        domain = getRepositoryDomain(token, appKey=appKey)

        custom_metrics = sort( collect(keys(domain["custom_metrics"])), by = k -> domain["custom_metrics"][k]["index"] )

        results["columnNames"] = [dimension; custom_metrics]
    end

    df = resultsToDataFrame(results["columnNames"], :metrics, results["data"])

    ns = names(df)
    rename!(df, 1 => string(dimension))

    return df
end




"""
Calls the `timers-metrics` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions"))

`Exception`
:    If there was an unexpected type error parsing response values

### Returns
`{DataFrame}` A `DataFrame` with one column for each timer and metric.  Known columns include:

* `:Beacons` and `:PageLoad` will always be present.
* `:Sessions` and `:BounceRate` will be present if session tracking is enabled (on by default)
* `:DNS`, `:TCP`, `:SSL`, `:FirstByte`, `:DomLoad`, `:DomReady` and `:FirstLastByte` will be present if NavigationTiming is available (almost always available)
* Custom Timers & Custom Metrics are included if defined and if they have data for the selected time period

The last row in the DataFrame is the latest value of the timer or metric.  All preceding rows are historic values over the time period broken down by a predefined time unit.
For example, for Last24Hours, there will be 1440 entries representing each minute in the 24 hour period.

```julia
julia> mPulseAPI.getTimersMetrics(token, appKey)
1441x16 DataFrames.DataFrame
| Row  | PageLoad | DNS | DomLoad | DomReady | FirstByte | SSL | FirstLastByte | TCP | DOM Interactive | Sessions | BounceRate | Conversion | OrderTotal | Beacons |
|------|----------|-----|---------|----------|-----------|-----|---------------|-----|-----------------|----------|------------|------------|------------|---------|
| 1    | 3442     │ 46  │ 805     │ 3345     │ 732       │ 59  │ 2468          │ 36  │ 1696            │ 353      │ 34         │ 0.566572   │ 58652.0    │ 1808    │
| 2    | 3308     | 45  | 758     | 3173     | 705       | 56  | 2351          | 32  | 1620            | 331      | 30         | 2.1148     | 266219.0   | 1767    |
| 3    | 3412     | 38  | 794     | 3287     | 726       | 69  | 2360          | 31  | 1707            | 346      | 29         | 1.44509    | 209205.0   | 1806    |
| 4    | 3368     | 40  | 775     | 3250     | 701       | 51  | 2500          | 34  | 1670            | 354      | 32         | 2.25989    | 47354.0    | 1850    |
| 5    | 3346     | 37  | 754     | 3222     | 691       | 61  | 2516          | 31  | 1624            | 326      | 30         | 2.76074    | 132915.0   | 1742    |
| 6    | 3162     | 36  | 729     | 3040     | 665       | 86  | 2283          | 30  | 1611            | 382      | 28         | 1.57068    | 117284.0   | 1803    |
| 7    | 3453     | 39  | 862     | 3320     | 787       | 64  | 2471          | 32  | 1772            | 356      | 33         | 2.52809    | 108045.0   | 1727    |
| 8    | 3593     | 46  | 1028    | 3491     | 889       | 92  | 2495          | 33  | 1952            | 314      | 33         | 1.27389    | 150020.0   | 1715    |
```
"""
function getTimersMetrics(token::AbstractString, appKey::AbstractString; filters::Dict=Dict())
    results = getAPIResults(token, appKey, "timers-metrics", filters=filters)

    df = DataFrame()
    nulls = Symbol[]

    for element in results["values"]
        name   = Symbol(element["id"])
        latest = element["latest"]

        # If we got a metric/timer without a name, and it actually has data, try to determine its name from the domain object
        if occursin(r"^Custom(Timer|Metric)\d+$", string(name))
            if latest != 0 && haskey(element, "history") && length(element["history"]) > 0

                # This is returned from in-memory cache on subsequent calls, so safe to call in a loop
                domain = getRepositoryDomain(token, appKey=appKey)

                # Invert and merge both maps
                custom = Dict(
                            [ Symbol("CustomMetric", v["index"]) => k for (k, v) in domain["custom_metrics"] ]
                            ∪
                            [ Symbol(v["mpulseapiname"]) => k for (k, v) in domain["custom_timers"] ]
                        )

                if haskey(custom, name)
                    name = custom[name]
                else
                    # Metric/timer had data, but wasn't actually defined in the app. mPulse bug 115779
                    @warn("Got data for $name but it does not exist for this app")
                    continue
                end
            else
                continue
            end
        end

        local i=0
        # Make sure column name is unique
        while name ∈ names(df) ∪ nulls
            i += 1
            name = Symbol(element["id"], "__", i)
        end

        # If latest is 0 and there's no history, then mark this column as NULL
        if latest == 0 && (!haskey(element, "history") || length(element["history"]) == 0)
            push!(nulls, name)
            continue
        end

        history = element["history"]

        etype = typeof(latest)

        # Make sure history is an array of numbers because sometimes mPulse wraps them in strings
        if isa(history[1], Real)
            history = Array{etype}(history)
        else
            try
                history = Array{etype}(map(h -> parse(etype, h), history))
            catch ex
                # Sometimes latest is an Int but history contains Floats
                if isa(ex, ArgumentError) && occursin(r"invalid base 10 digit '\.' in", ex.msg)
                    history = Array{Float64}(map(h -> parse(Float64, h), history))
                else
                    rethrow()
                end
            end
        end

        push!(history, latest)

        df[!, name] = history
    end

    for nullcol in nulls
        df[!, nullcol] = nullval
    end

    if nrow(df) > 1 && all(a -> ismissing(a) || a == 0, map(x -> df[end-1, x], names(df)))
        # mPulse bug 115785: If penultimate row is all 0s/missing, remove it
        return df[[1:end-2; end], :]
    else
        return df
    end
end




"""
Calls the `histogram` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions"))

$(mPulseAPI.readdocs("CleanSeriesSeries-exceptions"))

### Returns
`{Dict}` A Julia `Dict` with the following string keys:

`median::Int`
:   The median value for values in the histogram in milliseconds

`p95::Int`
:   The 95th percentile value for values in the histogram in milliseconds

`p98::Int`
:   The 98th percentile value for values in the histogram in milliseconds

`buckets::DataFrame`
:   Buckets for the histogram.  These buckets are variable width. See below for a description.


```julia
julia> histo = mPulseAPI.getHistogram(token, appKey)
Dict{AbstractString,Any} with 4 entries:
  "median"  => 3439
  "p95"     => 12843
  "p98"     => 22816
  "buckets" => 117x3 DataFrames.DataFrame…
```

The buckets `DataFrame` has the following columns: `:bucket_start`, `:bucket_end`, `:element_count`

```julia
julia> histo["buckets"]
117x3 DataFrames.DataFrame
| Row | bucket_start | bucket_end | element_count |
|-----|--------------|------------|---------------|
| 1   | 1            | 2          | 1             |
| 2   | 3            | 4          | 3             |
| 3   | 4            | 5          | 8             |
| 4   | 5            | 6          | 7             |
| 5   | 6            | 7          | 9             |
| 6   | 7            | 8          | 8             |
| 7   | 8            | 9          | 14            |
| 8   | 9            | 10         | 13            |
| 9   | 10           | 11         | 17            |
| 10  | 11           | 12         | 15            |
| 11  | 12           | 13         | 19            |
| 12  | 13           | 14         | 18            |
| 13  | 14           | 15         | 19            |
```
"""
function getHistogram(token::AbstractString, appKey::AbstractString; filters::Dict=Dict())
    results = getAPIResults(token, appKey, "histogram", filters=filters)

    results = cleanSeriesSeries(results)

    results["buckets"] = resultsToDataFrame( Symbol[:s, :e, :c], :hist, results["aPoints"] )
    rename!(results["buckets"], [ "bucket_start", "bucket_end", "element_count" ])

    delete!(results, "name")
    delete!(results, "aPoints")
    delete!(results, "kValue")
    delete!(results, "percentile_name")

    return results
end




"""
Calls the `sessions-per-page-load-time` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
$(mPulseAPI.readdocs("APIResults-common-optargs"))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions"))

### Returns
$(mPulseAPI.readdocs("MetricOverLoadTime-return-format", ["Sessions", "Sessions", 72, 36, 30, 66, 464, 749, 709, 1246]))
"""
function getSessionsOverPageLoadTime(token::AbstractString, appKey::AbstractString; filters::Dict=Dict())
    return getMetricOverPageLoadTime(token, appKey, filters=filters, metric="Sessions")
end




"""
Calls the `metric-per-page-load-time` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
`metric::AbstractString`
:    The name of the metric that we want data for.  If not specified, defaults to `BounceRate`

$(mPulseAPI.readdocs("APIResults-common-optargs"))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions", ["metric"]))

$(mPulseAPI.readdocs("CleanSeriesSeries-exceptions"))

### Returns
$(mPulseAPI.readdocs("MetricOverLoadTime-return-format", ["Metric", "BounceRate", "missing", 100.0, 68.57, 12.65, 71.08, 14.51, 20.83, 24.58]))
"""
function getMetricOverPageLoadTime(token::AbstractString, appKey::AbstractString; filters::Dict=Dict(), metric::AbstractString="")
    if metric != ""
        filters["metric"] = metric
    end
    metric = (haskey(filters, "metric") && filters["metric"] != "") ? filters["metric"] : metric != "" ? metric : "BounceRate"

    if metric == "Sessions"
        delete!(filters, "metric")
        results = getAPIResults(token, appKey, "sessions-per-page-load-time", filters=filters)
    else
        results = getAPIResults(token, appKey, "metric-per-page-load-time", filters=filters)
    end

    if isa(results, Dict) && haskey(results, "series") && results["series"] == nothing
        throw(mPulseAPIRequestException("Invalid Metric: $(metric)", "MPulseAPIException.InvalidParameter", "metric", metric, nothing))
    end

    results = cleanSeriesSeries(results)

    df = resultsToDataFrame( Symbol[:x, :y], :hist, results["aPoints"] )

    rename!(df, [ "t_done", string(metric) ])

    return df
end

const supported_timers = [
        "PageLoad",
        "DNS",
        "TCP",
        "SSL",
        "FirstByte",
        "DomLoad",
        "DomReady",
        "FirstLastByte"
    ]


"""
Calls the `by-minute` endpoint of the mPulse REST API with the passed in filters

### Arguments
$(mPulseAPI.readdocs("APIResults-common-args"))

### Keyword Arguments
`timer::AbstractString`
:    The name of the timer whose data we want.  If not specified, defaults to `PageLoad`.  Other possible
     values are:

$(join(map(x -> "     * $x", mPulseAPI.supported_timers), "\n"))
     * <all custom timers>

$(mPulseAPI.readdocs("APIResults-common-optargs"))

### Throws
$(mPulseAPI.readdocs("APIResults-exceptions", ["timer"]))

$(mPulseAPI.readdocs("CleanSeriesSeries-exceptions"))

### Returns
`{DataFrame}` A julia `DataFrame` containing timeseries data for the median value of the timer and its margin of error.
The fields are: `:timestamp` in milliseconds since the UNIX epoch, `:<TimerName>` in milliseconds and `:moe` in milliseconds.

```julia
julia> data = mPulseAPI.getTimerByMinute(token, appKey, timer="PageLoad")
1440x3 DataFrames.DataFrame
| Row  | timestamp     | PageLoad | moe  |
|------|---------------|----------|------|
| 1    | 1463452800000 | 3679     | 135  |
| 2    | 1463452860000 | 3731     | 202  |
| 3    | 1463452920000 | 3706     | 116  |
| 4    | 1463452980000 | 3911     | 171  |
| 5    | 1463453040000 | 3757     | 181  |
| 6    | 1463453100000 | 3729     | 174  |
| 7    | 1463453160000 | 3779     | 174  |
| 8    | 1463453220000 | 3916     | 182  |

```
"""
function getTimerByMinute(token::AbstractString, appKey::AbstractString; filters::Dict=Dict(), timer::AbstractString="")
    local orig_timer = timer

    if timer != "" && !startswith(timer, "CustomTimer") && timer ∉ supported_timers
        # Check if this is a known custom timer, and if it is, replace with CustomTimer<index>
        domain = getRepositoryDomain(token, appKey=appKey)

        if haskey(domain["custom_timers"], timer)
            timer = domain["custom_timers"][timer]["mpulseapiname"]
        else
            throw(mPulseAPIRequestException("$timer is not a valid timer name", "MPulseAPIException.InvalidParameter", "timer", timer, nothing))
        end
    end

    if timer != ""
        filters["timer"] = timer
    end
    timer = orig_timer != "" ? orig_timer : (haskey(filters, "timer") && filters["timer"] != "") ? filters["timer"] : "PageLoad"

    results = getAPIResults(token, appKey, "by-minute", filters=filters)

    results = cleanSeriesSeries(results)

    df = resultsToDataFrame( Symbol[:x, :y], :hist, results["aPoints"] )

    rename!(df, [ "timestamp", string(timer)])

    if size(df, 1) > 0
        df[!, :moe] = Vector{Int}(map(p -> haskey(p, "userdata") ? round(Int, 1000*JSON.parse(p["userdata"])["value"]) : 0, results["aPoints"]))
    else
        df[!, :moe] = Int[]
    end

    return df
end



"""
Merge multiple similar `DataFrames` into a single `DataFrame`

Use this method to merge the results from multiple calls to `getMetricOverPageLoadTime()` and `getSessionsOverPageLoadTime()`.
All passed in `DataFrame`s MUST contain a `:t_done` column.

### Arguments
`df1::DataFrame`
:    The first `DataFrame` in the collection.  This method requires at least one `DataFrame` to be passed in.

`df2::DataFrame...`
:    One or more `DataFrame` to be merged together with the first one

### Keyword Arguments
`keyField::Symbol=:t_done`
:    The column name to join on.  Defaults to `:t_done`

`joinType::Symbol=:outer`
:    The type of join to perform.  Could be `:inner`, `:outer`, `:left`, `:right`, `:cross`.

### Throws
`KeyError`
:    if the `keyField` column does not exist in all passed in `DataFrame`s

### Returns
* If only one `DataFrame` is passed in, it is returned as-is.  This is not a copy of the first DataFrame.
* If multiple `DataFrame`s are passed in, they are merged using an `outer` join on the `keyField` column, and the resulting `DataFrame` is returned.
  Since we perform an outer join, rows in any of the DataFrames that do not have a matching `keyField` value found in other DataFrames will be filled with `missing`

```julia
julia> sessions   = mPulseAPI.getSessionsOverPageLoadTime(token, appKey);
julia> bouncerate = mPulseAPI.getMetricOverPageLoadTime(token, appKey);
julia> conversion = mPulseAPI.getMetricOverPageLoadTime(token, appKey, metric="Conversion");

julia> mPulseAPI.mergeMetrics(sessions, bouncerate, conversion)
65x4 DataFrames.DataFrame
| Row | t_done | Sessions | BounceRate | Conversion |
|-----|--------|----------|------------|------------|
| 1   | 6      | 1        | missing    | missing    |
| 2   | 10     | 2        | 50.0       | missing    |
| 3   | 12     | 2        | 100.0      | missing    |
| 4   | 17     | 1        | 100.0      | missing    |
| 5   | 30     | 1        | 100.0      | missing    |
| 6   | 34     | 1        | missing    | missing    |
| 7   | 40     | 1        | 100.0      | missing    |
| 8   | 60     | 2        | 100.0      | missing    |
| 9   | 70     | 1        | 100.0      | missing    |
| 10  | 120    | 2        | 100.0      | missing    |
| 11  | 140    | 1        | missing    | missing    |
| 12  | 170    | 1        | missing    | missing    |
| 13  | 190    | 1        | 100.0      | missing    |
| 14  | 230    | 1        | missing    | missing    |
...
| 44  | 3750   | 8332     | 29.5915    | 2.25043    |
| 45  | 3950   | 7957     | 31.7591    | 2.08962    |
| 46  | 4200   | 7342     | 34.9953    | 2.02302    |
| 47  | 4500   | 6783     | 37.0922    | 1.59947    |
| 48  | 4800   | 6140     | 40.2336    | 1.67129    |
| 49  | 5100   | 5530     | 42.2393    | 1.32839    |
```
"""
function mergeMetrics(df1::DataFrame, df2::DataFrame...; keyField::Symbol=:t_done, joinType::Symbol=:outer)
    df = df1
    joinmethod = (Symbol(joinType, :join))
    if !isdefined(DataFrames, joinmethod)
        throw(ArgumentError("Unknown join type `$joinType`"))
    end

    joinmethod = getfield(DataFrames, joinmethod)

    df = joinmethod(df, df2...; on=keyField)

    sort!(df, keyField)
    return df
end




# Convenience method to clean up bad design choices made in mPulse's REST API
function cleanSeriesSeries(results::Dict)
    if !isa(results, Dict) || !haskey(results, "series") ||
            !isa(results["series"], Dict) || !haskey(results["series"], "series") ||
            !isa(results["series"]["series"], Array)
        throw(mPulseAPIResultFormatException("API response JSON did not have a `series` element", results))
    end

    if length(results["series"]["series"]) < 1
        results = Dict("aPoints" => [])
    else
        results = results["series"]["series"][1]
    end

    return results
end




const df_types_array = Dict(
                        # Median == Int,
                        # Measurements == Real; normally an Int, but can become Float64 if very large. Real is the first common supertype between Int & Float64 that isa() works with
                        # MoE & % == Float64; normally a string that needs to be parse()d to Float64, and parse() only accepts Int or Float64 as arguments
                            :primary => Type[AbstractString, Int, Float64, Real, Float64],

                            :metrics => Type[AbstractString, Real],

                            :hist    => Type[Real]

                        )

# Internal convenience method to convert results from /browsers/, /ab-tests/, /page-groups/, etc. to a DataFrame
resultsToDataFrame(names::Vector{Any}, types::Symbol, results::Nothing) = resultsToDataFrame(names, types, Nothing[])
resultsToDataFrame(names::Vector{Symbol}, types::Symbol, results::Nothing) = resultsToDataFrame(names, types, Nothing[])

function resultsToDataFrame(names::Vector{Any}, types::Symbol, results::Vector)
    return resultsToDataFrame(
                convert(Array{Symbol}, map(Symbol, names)),
                types,
                results
            )
end

function resultsToDataFrame(names::Vector{Symbol}, types::Symbol, results::Vector)
    df = DataFrame()

    types = df_types_array[types]

    for i in 1:length(names)
        local t = types[min(i, end)]
        local n = names[i]

        df[!, n] = Array{t}(
                    map(results) do row
                        # First make sure the row is in a recognized format
                        if isa(row, Array)
                            value = row[i]
                        elseif isa(row, Dict)
                            value = row[string(n)]
                        else
                            throw(mPulseAPIResultFormatException("Unknown row type: $(typeof(row))", row))
                        end

                        # Next convert the element into the required type
                        if value == nothing || isa(value, t)
                            return value
                        elseif t == AbstractString
                            return string(value)
                        elseif t == Real
                            return occursin(r"\.", value) ? parse(Float64, value) : parse(Int, value, base=10)
                        else
                            return parse(t, value)
                        end
                    end
                )
    end

    return df
end
