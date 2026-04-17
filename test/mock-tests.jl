# Tests using Test.GenericString dispatch to exercise code paths that require HTTP
# responses, without making real HTTP calls.
#
# Pattern: Julia dispatches on the most specific type. By defining overloads with
# `token::Test.GenericString` (a subtype of AbstractString), we intercept internal
# API calls while leaving the real AbstractString methods untouched.
#
# Test.GenericString implements == against AbstractString, so token comparisons
# like `token == "testEmpty"` work without converting to String first.

import mPulseAPI.getAPIResults
import mPulseAPI.getRepositoryDomain
import mPulseAPI.getHttpRequest
import mPulseAPI.HTTP

# ---------------------------------------------------------------------------
# Mock: getAPIResults
# Intercepts all Query API calls. Token string selects the mock scenario.
# ---------------------------------------------------------------------------
function getAPIResults(
    token::Test.GenericString,
    appKey::AbstractString,
    query_type::AbstractString;
    filters::Dict = Dict()
)
    if token == "testEmpty"
        # Simulate API returning no results (empty Dict, length == 0)
        return Dict()

    elseif token == "testNullData"
        # Simulate API returning null data with valid column names
        return Dict("columnNames" => Any["browser", "Metric1"], "data" => nothing)

    elseif token == "testBadCols"
        # Simulate API returning CustomMetric column names — triggers domain fallback
        return Dict("columnNames" => Any["browser", "CustomMetric0"], "data" => Any[])

    elseif token == "testTimersMock"
        # Simulate timers-metrics response with:
        #   - NullTimer:      latest=0, no history → null column (L539-541)
        #   - CustomTimer0:   Custom* regex match, latest=0 → outer else → continue (L522)
        #   - CustomMetric0:  Custom* regex match, has data, in domain → name resolved (L518)
        #   - CustomMetric99: Custom* regex match, has data, NOT in domain → @warn + continue (L520-521)
        #   - PageLoad:       string history values → string-parsing path (L552-553)
        #   - FloatTimer:     Int latest with float string history → Float64 fallback (L554-559)
        # PageLoad's penultimate row = 1000 (non-zero) → no-prune path (L577).
        return Dict("values" => Any[
            Dict("id" => "NullTimer",      "latest" => 0),
            Dict("id" => "CustomTimer0",   "latest" => 0),
            Dict("id" => "CustomMetric0",  "latest" => 1000, "history" => Any[900, 950]),
            Dict("id" => "CustomMetric99", "latest" => 1000, "history" => Any[900, 950]),
            Dict("id" => "PageLoad",       "latest" => 1500, "history" => Any["500", "1000"]),
            Dict("id" => "FloatTimer",     "latest" => 1000, "history" => Any["3.14", "5.23"]),
        ])

    elseif token == "testPruneMock"
        # Simulate timers-metrics response where the penultimate row is all zeros,
        # triggering the mPulse bug 115785 prune path (L573-575).
        return Dict("values" => Any[
            Dict("id" => "PageLoad", "latest" => 1500, "history" => Any[500, 0]),
        ])

    elseif token == "testNullSeries"
        # Simulate getMetricOverPageLoadTime response with null series (L720).
        return Dict("series" => nothing)
    end

    return Dict()
end

# ---------------------------------------------------------------------------
# Mock: getRepositoryDomain
# Needed by getMetricsByDimension when column names are bad/CustomMetric.
# ---------------------------------------------------------------------------
function getRepositoryDomain(
    token::Test.GenericString;
    domainID::Int64         = 0,
    appKey::AbstractString  = "",
    appName::AbstractString = "",
    appID::AbstractString   = "",
    filters::Dict{Symbol, Any} = Dict{Symbol, Any}()
)
    return Dict(
        "custom_metrics" => Dict(
            "Conversion"  => Dict("index" => 0),
            "OrderTotal"  => Dict("index" => 1),
        ),
        "custom_timers" => Dict(),
    )
end

# ---------------------------------------------------------------------------
# Mock: getHttpRequest
# Intercepts RepositoryAPI's internal HTTP call. Returns a minimal object list
# so that getRepositoryObject can exercise the isKeySet=true return path (L53).
# ---------------------------------------------------------------------------
function getHttpRequest(
    token::Test.GenericString,
    objectType::AbstractString,
    searchKey::Dict{Symbol, Any},
    isKeySet::Bool
)
    return [Dict{String, Any}("id" => 99, "name" => "MockObject")]
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@testset "QueryAPI (mocked)" begin

    @testset "Empty results → empty DataFrame" begin
        # Covers L245 (getPageGroupTimers), L283 (getBrowserTimers),
        # L321 (getABTestTimers), L359 (getGeoTimers): each returns DataFrame()
        t = Test.GenericString("testEmpty")
        @test isempty(mPulseAPI.getPageGroupTimers(t, "key"))
        @test isempty(mPulseAPI.getBrowserTimers(t, "key"))
        @test isempty(mPulseAPI.getABTestTimers(t, "key"))
        @test isempty(mPulseAPI.getGeoTimers(t, "key"))
    end

    @testset "getMetricsByDimension empty results → domain fallback" begin
        # Covers L425-426 (length==0 → default columnNames),
        # L433-440 (empty columnNames → getRepositoryDomain lookup),
        # L443-448 (resultsToDataFrame + rename)
        t = Test.GenericString("testEmpty")
        df = mPulseAPI.getMetricsByDimension(t, "key", "browser")
        @test "browser"    ∈ names(df)
        @test "Conversion" ∈ names(df)
        @test "OrderTotal" ∈ names(df)
        @test size(df, 1) == 0
    end

    @testset "getMetricsByDimension null data" begin
        # Covers L429-430 (data == nothing → reassign to [])
        t = Test.GenericString("testNullData")
        df = mPulseAPI.getMetricsByDimension(t, "key", "browser")
        @test "browser" ∈ names(df)
        @test "Metric1" ∈ names(df)
        @test size(df, 1) == 0
    end

    @testset "getMetricsByDimension CustomMetric columns → domain fallback" begin
        # Covers L433 (startswith CustomMetric condition) and L436-440
        t = Test.GenericString("testBadCols")
        df = mPulseAPI.getMetricsByDimension(t, "key", "browser")
        @test "browser"    ∈ names(df)
        @test "Conversion" ∈ names(df)
        @test size(df, 1) == 0
    end

    @testset "getTimersMetrics null column, string/float history, no row pruning" begin
        # Covers L539-541 (NullTimer: latest=0 → push to nulls),
        # L522 (CustomTimer0: Custom* match, latest=0 → outer else → continue),
        # L518 (CustomMetric0: in domain → name resolved to "Conversion"),
        # L520-521 (CustomMetric99: not in domain → @warn + continue),
        # L552-553 (PageLoad: string history → parse path),
        # L554-559 (FloatTimer: Int latest + float-string history → Float64 fallback),
        # L570 (df[!, nullcol] = nullval for NullTimer),
        # L577 (penultimate row of PageLoad = 1000 ≠ 0 → else return df)
        t = Test.GenericString("testTimersMock")
        df = mPulseAPI.getTimersMetrics(t, "key")
        @test "PageLoad"   ∈ names(df)
        @test "NullTimer"  ∈ names(df)
        @test "Conversion" ∈ names(df)        # CustomMetric0 resolved via domain
        @test "FloatTimer" ∈ names(df)        # Float64 fallback path
        @test "CustomMetric99" ∉ names(df)    # not in domain → skipped
        @test "CustomTimer0"   ∉ names(df)    # latest=0 → skipped
        @test all(ismissing, df[!, :NullTimer])
        @test eltype(df[!, :FloatTimer]) == Float64
        @test nrow(df) == 3   # 3 rows kept: no pruning (penultimate row has data)
    end

    @testset "getTimersMetrics penultimate-row prune (mPulse bug 115785)" begin
        # Covers L573-575: penultimate row all zeros → remove it, return [1:end-2; end]
        t = Test.GenericString("testPruneMock")
        df = mPulseAPI.getTimersMetrics(t, "key")
        @test "PageLoad" ∈ names(df)
        @test nrow(df) == 2   # 3 rows (500, 0, 1500) → pruned to 2 (500, 1500)
        @test df[end, :PageLoad] == 1500
    end

    @testset "getMetricOverPageLoadTime null series → mPulseAPIRequestException" begin
        # Covers L719-720: results["series"] == nothing → throw
        t = Test.GenericString("testNullSeries")
        @test_throws mPulseAPIRequestException mPulseAPI.getMetricOverPageLoadTime(t, "key", metric="FakeMetric")
    end

    @testset "getTimerByMinute invalid timer → mPulseAPIRequestException" begin
        # Covers L795: timer not in custom_timers domain → throw
        # getRepositoryDomain mock returns custom_timers={}, so any non-standard timer name throws.
        t = Test.GenericString("testEmpty")
        @test_throws mPulseAPIRequestException mPulseAPI.getTimerByMinute(t, "key", timer="NotATimer")
    end

end

# ---------------------------------------------------------------------------
# Mock: HTTP.post
# Intercepts postHttpRequest's outbound POST call. URL string selects the
# mock scenario so we can exercise all status-code branches without a server.
# ---------------------------------------------------------------------------
function HTTP.post(url::Test.GenericString, args...; kwargs...)
    if url == "url-400"
        return mPulseAPI.HTTP.Response(400)
    elseif url == "url-404"
        return mPulseAPI.HTTP.Response(404)
    elseif url == "url-204"
        return mPulseAPI.HTTP.Response(204)
    elseif url == "url-401"
        return mPulseAPI.HTTP.Response(401)
    elseif url == "url-500"
        return mPulseAPI.HTTP.Response(500)
    else
        throw(ArgumentError("Unexpected mock POST URL: $(repr(url))"))
    end
end

# ---------------------------------------------------------------------------
# Mock: HTTP.get
# Overrides HTTP.get for String URLs, dispatching on the X-Auth-Token header
# value. Non-mock tokens pass through to HTTP.request("GET", ...) so live tests
# are unaffected.
# ---------------------------------------------------------------------------
function HTTP.get(url::String, args...; kwargs...)
    headers = length(args) >= 1 ? args[1] : nothing
    token   = headers isa AbstractDict ? Base.get(headers, "X-Auth-Token", "") : ""

    if token == "mock-get-500"
        return mPulseAPI.HTTP.Response(500)
    elseif token == "mock-get-503"
        return mPulseAPI.HTTP.Response(503)
    elseif token == "mock-get-empty"
        return mPulseAPI.HTTP.Response(200, Vector{UInt8}("""{"objects":[]}"""))
    elseif token == "mock-get-multi"
        return mPulseAPI.HTTP.Response(200, Vector{UInt8}("""{"objects":[{"id":1},{"id":2}]}"""))
    else
        return mPulseAPI.HTTP.request("GET", url, args...; kwargs...)
    end
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@testset "buildPostJSON" begin
    # objectFields path (L253-256): fields are merged into the JSON dict
    json = mPulseAPI.buildPostJSON("domain", 1, Dict("description" => "Test App"))
    @test json["description"] == "Test App"
    @test json["type"] == "domain"

    # attributes path (L230-248): attributes become an array of name/value dicts
    json = mPulseAPI.buildPostJSON("domain", 1, Dict(), Dict(), Dict("color" => "blue"))
    @test any(a -> a["name"] == "color" && a["value"] == "blue", json["attributes"])

    # statisticalmodel attribute merge (L233-240): old keys not in new attributes are merged in
    json = mPulseAPI.buildPostJSON(
        "statisticalmodel", 1, Dict(),
        Dict("existing_key" => "keep_me", "overridden_key" => "old_val"),
        Dict("overridden_key" => "new_val")
    )
    attrs = Dict(a["name"] => a["value"] for a in json["attributes"])
    @test attrs["existing_key"]  == "keep_me"   # copied from oldAttributes
    @test attrs["overridden_key"] == "new_val"  # new value wins

    # body as XML string (L261-273): parsed and stored as-is
    json = mPulseAPI.buildPostJSON("domain", 1, Dict(), Dict(), Dict(), "<root/>")
    @test json["body"] == "<root/>"

    # body as XMLElement (L274-276): converted to string
    xdoc  = mPulseAPI.LightXML.XMLDocument()
    xroot = mPulseAPI.LightXML.create_root(xdoc, "root")
    json  = mPulseAPI.buildPostJSON("domain", 1, Dict(), Dict(), Dict(), xroot)
    @test occursin("root", json["body"])
end

@testset "postHttpRequest (mocked)" begin
    json = Dict{AbstractString, Any}("type" => "domain", "id" => 0)

    # 400 → mPulseAPIException (L180-181)
    @test_throws mPulseAPIException mPulseAPI.postHttpRequest(
        Test.GenericString("url-400"), "domain", 0, json, "tok")

    # 404 → mPulseAPIException (L180-181, same branch)
    @test_throws mPulseAPIException mPulseAPI.postHttpRequest(
        Test.GenericString("url-404"), "domain", 0, json, "tok")

    # 204 → success, returns response (L184)
    resp = mPulseAPI.postHttpRequest(Test.GenericString("url-204"), "domain", 0, json, "tok")
    @test resp.status == 204
end

@testset "handlePostResponse (mocked)" begin
    json = Dict{AbstractString, Any}("type" => "domain", "id" => 0)

    # 204 on first attempt → returns immediately (L197-198)
    resp = mPulseAPI.handlePostResponse(
        Test.GenericString("url-204"), "domain", 0, json, "tok")
    @test resp.status == 204

    # 401 on 2nd attempt (for attempt in 1:5, attempt > 1 on 2nd pass)
    # → throws mPulseAPIAuthException (L200-201)
    @test_throws mPulseAPIAuthException mPulseAPI.handlePostResponse(
        Test.GenericString("url-401"), "domain", 0, json, "tok")

    # 500 repeated → loop exhausts after 5 attempts, then throws mPulseAPIBugException (L205-206)
    @test_throws mPulseAPIBugException mPulseAPI.handlePostResponse(
        Test.GenericString("url-500"), "domain", 0, json, "tok")
end

@testset "readdocs" begin

    @testset "No replacers — plain file read" begin
        # Covers L103-104 (readchomp). While loop never fires, Format.format skipped.
        result = mPulseAPI.readdocs("APIResults-common-args")
        @test occursin("token::AbstractString", result)
        @test occursin("appKey::AbstractString", result)
    end

    @testset "Explicit replacers — format substitution" begin
        # Covers L120-131 (Format.format path). {1} → "Page Group", {2} → "page_group".
        result = mPulseAPI.readdocs("friendly-names", ["Page Group", "page_group"])
        @test occursin("Page Group", result)
        @test occursin("page_group", result)
    end

    @testset "Default placeholder extraction" begin
        # Covers L108-117 (while loop, resize!, default assignment).
        # APIResults-exceptions.md has {1=request parameter}; with no explicit
        # replacer the default is extracted and used by Format.format.
        result = mPulseAPI.readdocs("APIResults-exceptions")
        @test occursin("request parameter", result)
    end

    @testset "Explicit replacer overrides default" begin
        # Covers L114 false-branch: length(replacers) >= id so default is not stored.
        # CleanSeriesSeries-exceptions.md has {1=a missing `series` element or}.
        result = mPulseAPI.readdocs("CleanSeriesSeries-exceptions", ["custom error"])
        @test occursin("custom error", result)
        @test !occursin("missing", result)
    end

    @testset "indent > 0" begin
        # Covers L134-135: every line gets a leading indent.
        result = mPulseAPI.readdocs("APIResults-common-args", indent=4)
        @test all(line -> isempty(line) || startswith(line, "    "), split(result, "\n"))
    end

end

@testset "RepositoryAPI (mocked)" begin

    @testset "getRepositoryObject isKeySet path" begin
        # Covers L53: when isKeySet=true and cache misses, getHttpRequest is called
        # and object_list[1] is returned (not the full list).
        t = Test.GenericString("testSingle")
        result = mPulseAPI.getRepositoryObject(t, "domain", Dict{Symbol, Any}(:id => 99))
        @test result["id"] == 99
    end

end

@testset "getHttpRequest (mocked)" begin

    @testset "500 response → mPulseAPIBugException (L309-310)" begin
        @test_throws mPulseAPI.mPulseAPIBugException mPulseAPI.getRepositoryObject(
            "mock-get-500", "domain", Dict{Symbol, Any}(:id => 0, :name => ""); filterRequired=false
        )
    end

    @testset "non-200 response → mPulseAPIException (L311-312)" begin
        @test_throws mPulseAPI.mPulseAPIException mPulseAPI.getRepositoryObject(
            "mock-get-503", "domain", Dict{Symbol, Any}(:id => 0, :name => ""); filterRequired=false
        )
    end

    @testset "empty list, no key → 'no objects defined' (L330-331)" begin
        # debugID stays "(all)" when all searchKey values are zero/empty and filterRequired=false
        @test_throws mPulseAPI.mPulseAPIException mPulseAPI.getRepositoryObject(
            "mock-get-empty", "domain", Dict{Symbol, Any}(:id => 0, :name => ""); filterRequired=false
        )
    end

    @testset "empty list, with key → 'not returned' (L332-333)" begin
        # debugID becomes "id=99" when searchKey has a non-zero value
        @test_throws mPulseAPI.mPulseAPIException mPulseAPI.getRepositoryObject(
            "mock-get-empty", "domain", Dict{Symbol, Any}(:id => 99)
        )
    end

    @testset "too many results → mPulseAPIException (L336-337)" begin
        @test_throws mPulseAPI.mPulseAPIException mPulseAPI.getRepositoryObject(
            "mock-get-multi", "domain", Dict{Symbol, Any}(:id => 1)
        )
    end

end

@testset "Tenant and StatisticalModel (cache-wrap)" begin

    @testset "Tenant: Dict from cache → wrapped to Array (Tenant.jl L95-96)" begin
        # When a Dict (not Array) comes back from cache, it must be wrapped.
        # Pre-populate with dswbUrls present so the parse block (L101-103) is skipped.
        cached = Dict{String, Any}("id" => 42, "dswbUrls" => ["http://example.com"])
        mPulseAPI.writeObjectToCache("tenant", Dict{Symbol, Any}(:id => 42), cached)
        result = mPulseAPI.getRepositoryTenant("sometoken"; tenantID=42)
        @test result["id"] == 42
        @test result["dswbUrls"] == ["http://example.com"]
    end

    @testset "Tenant: Dict from cache without dswbUrls → parsed from body (L101-103)" begin
        # No dswbUrls in cached object → getNodeContent called on body XML (L101-103).
        xdoc  = mPulseAPI.LightXML.parse_string("<tenant><DSWBURLs>http://a.com,http://b.com</DSWBURLs></tenant>")
        xroot = mPulseAPI.LightXML.root(xdoc)
        cached = Dict{String, Any}("id" => 43, "body" => xroot)
        mPulseAPI.writeObjectToCache("tenant", Dict{Symbol, Any}(:id => 43), cached)
        result = mPulseAPI.getRepositoryTenant("sometoken"; tenantID=43)
        @test result["id"] == 43
        @test result["dswbUrls"] == ["http://a.com", "http://b.com"]
    end

    @testset "StatisticalModel: Dict from cache → wrapped to Array (StatisticalModel.jl L112-113)" begin
        cached = Dict{String, Any}("id" => 77, "name" => "TestModel")
        mPulseAPI.writeObjectToCache("statisticalmodel", Dict{Symbol, Any}(:id => 77), cached)
        result = mPulseAPI.getRepositoryStatModel("sometoken"; statModelID=77)
        @test result["id"] == 77
        @test result["name"] == "TestModel"
    end

end
