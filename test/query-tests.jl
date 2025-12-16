using DataFrames, HTTP

token  = getRepositoryToken(mPulseAPITenant, mPulseAPIToken)
domain = getRepositoryDomain(token, appName="mPulse Demo")
appKey = domain["attributes"]["appKey"]

hasDemoData = true

@testset "Summary" begin
    # We need to add a random string to the appKey to cache bust API results from the previous test
    @test_throws mPulseAPIAuthException mPulseAPI.getSummaryTimers("invalid-token", appKey * "-" * string(round(Int, rand()*100000), base=16, pad=5))
    @test_throws mPulseAPIRequestException mPulseAPI.getSummaryTimers(token, appKey, filters = Dict("invalid-token" => "foo"))

    summary = mPulseAPI.getSummaryTimers(token, appKey)

    @test length(summary) == 5

    if summary["n"] != nothing
        @test isa(summary["n"], Int)
        @test isa(summary["median"], Int)
        @test isa(summary["p95"], Int)
        @test isa(summary["p98"], Int)
        @test isa(summary["moe"], Float64)
    else
        @warn("mPulse Demo app has no demo data")
        global hasDemoData = false
    end
end


@testset "Dimensions" begin
    function testDimensionTable(mtd, first_symbol, first_friendly, has_moe=true)
        local x = "--"
        try
            x = getfield(mPulseAPI, mtd)(token, appKey)

            @test size(x, 2) == 5-(!has_moe)
            @test names(x) == map(string, [first_symbol, :t_done_median] ∪ (has_moe ? [:t_done_moe] : []) ∪ [:t_done_count, :t_done_total_pc])

            x = getfield(mPulseAPI, mtd)(token, appKey, friendly_names=true)
            @test size(x, 2) == 5-(!has_moe)
            @test names(x) == [string(first_friendly), "Median Time (ms)"] ∪ (has_moe ? ["MoE (ms)"] : []) ∪ ["Measurements", "% of total"]
        catch ex
            @warn("mPulseAPI.$mtd")
            show(x)
            println()
            if :response ∈ fieldnames(typeof(ex)) && isa(ex.response, HTTP.Response)
                show(ex.response)
                println()
            end
            rethrow(ex)
        end
    end

    @testset "Page Groups" begin
        testDimensionTable(:getPageGroupTimers, :page_group, "Page Group")
    end

    @testset "Browsers" begin
        testDimensionTable(:getBrowserTimers, :user_agent, "User Agent")
    end

    @testset "ABTests" begin
        testDimensionTable(:getABTestTimers, :test_name, "Test Name")
    end

    @testset "Geo" begin
        testDimensionTable(:getGeoTimers, :country, "Country", false)
    end
end

@testset "MetricsByDimension" begin
    for dimension in ["browser", "page_group", "country", "bw_block", "ab_test"]
        local metrics = []
        try
            metrics = mPulseAPI.getMetricsByDimension(token, appKey, dimension)

            @test size(metrics, 2) == 1 + length(domain["custom_metrics"])
            @test sort(names(metrics)) == sort(map(string, [ dimension; collect(keys(domain["custom_metrics"])) ]))

            hasDemoData && @test size(metrics, 1) > 0
        catch ex
            @warn("mPulseAPI.getMetricsByDimension:$dimension")
            show(metrics)
            println()
            if :response ∈ fieldnames(typeof(ex)) && isa(ex.response, HTTP.Response)
                show(ex.response)
                println()
            end
            rethrow(ex)
        end
    end

    @test_throws mPulseAPIRequestException mPulseAPI.getMetricsByDimension(token, appKey, "some-fake-dimension")
end


@testset "TimersMetrics" begin
    tm = mPulseAPI.getTimersMetrics(token, appKey)

    fixed_cols = [:Beacons, :PageLoad] # mPulse now only returns Beacons & PageLoad by default
    # fixed_cols = [:Beacons, :PageLoad, :Sessions, :BounceRate, :DNS, :TCP, :SSL, :FirstByte, :DomLoad, :DomReady, :FirstLastByte]
    varia_cols = Symbol[] #map(Symbol, [collect(keys(domain["custom_timers"])); collect(keys(domain["custom_metrics"]))])

    @test size(tm, 2) == length(fixed_cols ∪ varia_cols)

    @test sort(names(tm)) == sort(map(string, fixed_cols ∪ varia_cols))

    if hasDemoData
        @test size(tm, 1) == 1441

        tm = mPulseAPI.getTimersMetrics(token, appKey, filters=Dict("page-group" => ["Account", "Search"]))

        fixed_cols = [:Beacons, :PageLoad] # mPulse now only returns Beacons & PageLoad by default
        # fixed_cols = [:Beacons, :PageLoad, :Sessions, :BounceRate, :DNS, :TCP, :SSL, :FirstByte, :DomLoad, :DomReady, :FirstLastByte]
        varia_cols = Symbol[] #map(Symbol, [collect(keys(domain["custom_timers"])); collect(keys(domain["custom_metrics"]))])

        @test size(tm, 2) >= length(fixed_cols)

        @test size(tm, 1) == 1441
    end
end


@testset "Histogram" begin

    hgm = mPulseAPI.getHistogram(token, appKey)

    @test length(hgm) == 4

    if hasDemoData
        @test isa(hgm["median"], Int)
        @test isa(hgm["p95"], Int)
        @test isa(hgm["p98"], Int)
    end

    @test isa(hgm["buckets"], DataFrame)

    @test size(hgm["buckets"], 2) == 3
    @test names(hgm["buckets"]) == ["bucket_start", "bucket_end", "element_count"]
    for col in names(hgm["buckets"])
        @test eltype(hgm["buckets"][!, col]) <: Real
    end
end


@testset "Sessions/Metrics OverPageLoadTime" begin
    metric_frames = []
    metrics = [
        (:getSessionsOverPageLoadTime, :Sessions),
        (:getMetricOverPageLoadTime, :BounceRate)
    ] ∪ map(m -> (:getMetricOverPageLoadTime, Symbol(m), m), collect(keys(domain["custom_metrics"])))
    for tpl in metrics
        local x = nothing
        try
            if length(tpl) == 3
                x = getfield(mPulseAPI, tpl[1])(token, appKey, metric=tpl[3])
            else
                x = getfield(mPulseAPI, tpl[1])(token, appKey)
            end

            push!(metric_frames, x)

            @test size(x, 2) == 2
            @test names(x) == ["t_done", string(tpl[2])]

            hasDemoData && @test size(x, 1) > 0
        catch ex
            @warn("mPulseAPI.$(tpl[1])", length(tpl) == 3 ? ":$(tpl[3])" : "")
            show(x)
            println()
            if :response ∈ fieldnames(typeof(ex)) && isa(ex.response, HTTP.Response)
                show(ex.response)
                println()
            end

            rethrow(ex)
        end
    end

    # MergeMetrics
    merged_frame = mPulseAPI.mergeMetrics(metric_frames...)

    @test size(merged_frame, 2) == 3 + length(domain["custom_metrics"])
    @test names(merged_frame) == ["t_done", "Sessions", "BounceRate"] ∪ map(string, collect(keys(domain["custom_metrics"])))
    hasDemoData && @test size(merged_frame, 1) > 0
end


@testset "TimerByMinute" begin
    for timer in mPulseAPI.supported_timers ∪ collect(keys(domain["custom_timers"]))
        local tbm = []
        try
            tbm = mPulseAPI.getTimerByMinute(token, appKey, timer=timer)

            if timer == "ResourceTimer" || !hasDemoData
                @test size(tbm) == (0, 3)                                   # ResourceTimer has no data
            else
                @test size(tbm) == (1440, 3) || size(tbm) == (1439, 3)      # The mPulse API will sometimes not return the last minute of the day
            end
            @test names(tbm) == ["timestamp", string(timer), "moe"]
        catch ex
            @warn("mPulseAPI.getTimerByMinute($timer)")
            show(tbm)
            println()
            if :response ∈ fieldnames(typeof(ex)) && isa(ex.response, HTTP.Response)
                show(ex.response)
                println()
            end

            rethrow(ex)
        end
    end

    @test_throws mPulseAPIRequestException mPulseAPI.getTimerByMinute(token, appKey, timer="Some-Bad-Timer")
end
