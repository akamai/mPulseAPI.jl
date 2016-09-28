using DataFrames

token  = getRepositoryToken(mPulseAPITenant, mPulseAPIToken)
domain = getRepositoryDomain(token, appName="mPulse Demo")
appID  = domain["attributes"]["appID"]

# Summary
# We need to add a random string to the appID to cache bust API results from the previous test
@test_throws mPulseAPIAuthException mPulseAPI.getSummaryTimers("invalid-token", appID * "-" * base(16, round(Int, rand()*100000), 5))
@test_throws mPulseAPIRequestException mPulseAPI.getSummaryTimers(token, appID, filters = Dict("invalid-token" => "foo"))

summary = mPulseAPI.getSummaryTimers(token, appID)

@test length(summary) == 5

@test isa(summary["n"], Int)
@test isa(summary["median"], Int)
@test isa(summary["p95"], Int)
@test isa(summary["p98"], Int)
@test isa(summary["moe"], Float64)


function testDimensionTable(method, first_symbol, first_friendly)
    local x
    try
        x = getfield(mPulseAPI, method)(token, appID)
    
        @test size(x, 2) == 5
        @test names(x) == [first_symbol, :t_done_median, :t_done_moe, :t_done_count, :t_done_total_pc]
    
        x = getfield(mPulseAPI, method)(token, appID, friendly_names=true)
        @test size(x, 2) == 5
        @test names(x) == [symbol(first_friendly), symbol("Median Time (ms)"), symbol("MoE (ms)"), symbol("Measurements"), symbol("% of total")]
    catch ex
        warn("mPulseAPI.$method")
        show(x)
        println()
        rethrow(ex)
    end
end

# Page Groups
testDimensionTable(:getPageGroupTimers, :page_group, "Page Group")

# Browsers
testDimensionTable(:getBrowserTimers, :user_agent, "User Agent")

# ABTests
testDimensionTable(:getABTestTimers, :test_name, "Test Name")

# Geo
testDimensionTable(:getGeoTimers, :country, "Country")

# MetricsByDimension

for dimension in ["browser", "page_group", "country", "bw_block", "ab_test"]
    local metrics
    try
        metrics = mPulseAPI.getMetricsByDimension(token, appID, dimension)
    
        @test size(metrics, 2) == 1 + length(domain["custom_metrics"])
        @test sort(names(metrics)) == sort(map(symbol, [ dimension; collect(keys(domain["custom_metrics"])) ]))

        # Bandwidth testing is disabled for the mPulse Demo app, so we should have 0 rows for this dimension
        if dimension == "bw_block"
            @test size(metrics, 1) == 0
        else
            @test size(metrics, 1) > 0
        end
    catch ex
        warn("mPulseAPI.getMetricsByTimension:$dimension")
        show(metrics)
        println()
        rethrow(ex)
    end
end

@test_throws mPulseAPIRequestException mPulseAPI.getMetricsByDimension(token, appID, "some-fake-dimension")


# TimersMetrics
tm = mPulseAPI.getTimersMetrics(token, appID)

fixed_cols = [:Beacons, :PageLoad, :Sessions, :BounceRate, :DNS, :TCP, :SSL, :FirstByte, :DomLoad, :DomReady, :FirstLastByte]
varia_cols = map(symbol, [collect(keys(domain["custom_timers"])); collect(keys(domain["custom_metrics"]))])

@test size(tm, 2) == length(fixed_cols ∪ varia_cols)

@test sort(names(tm)) == sort(fixed_cols ∪ varia_cols)

@test size(tm, 1) == 1441


# Histogram

hgm = mPulseAPI.getHistogram(token, appID)

@test length(hgm) == 4
@test isa(hgm["median"], Int)
@test isa(hgm["p95"], Int)
@test isa(hgm["p98"], Int)
@test isa(hgm["buckets"], DataFrame)

@test size(hgm["buckets"], 2) == 3
@test names(hgm["buckets"]) == [:bucket_start, :bucket_end, :element_count]
for col in names(hgm["buckets"])
    @test isa(hgm["buckets"][col], DataArrays.DataArray{Real,1})
end


# Sessions/Metrics OverPageLoadTime
metric_frames = []
metrics = [
    (:getSessionsOverPageLoadTime, :Sessions),
    (:getMetricOverPageLoadTime, :BounceRate)
] ∪ map(m -> (:getMetricOverPageLoadTime, symbol(m), m), collect(keys(domain["custom_metrics"])))
for tuple in metrics
    local x
    try
        if length(tuple) == 3
            x = getfield(mPulseAPI, tuple[1])(token, appID, metric=tuple[3])
        else
            x = getfield(mPulseAPI, tuple[1])(token, appID)
        end

        push!(metric_frames, x)
    
        @test size(x, 2) == 2
        @test names(x) == [:t_done, tuple[2]]

        if length(tuple) == 3 && tuple[3] == "OrderTotal"
            # This test will fail when Bug 108727 is fixed so we'll get alerted about that
            @test size(x, 1) == 0
        else
            @test size(x, 1) > 0
        end
    catch ex
        warn("mPulseAPI.$(tuple[1])", length(tuple) == 3 ? ":$(tuple[3])" : "")
        show(x)
        println()

        rethrow(ex)
    end
end

# MergeMetrics
merged_frame = mPulseAPI.mergeMetrics(metric_frames...)

@test size(merged_frame, 2) == 3 + length(domain["custom_metrics"])
@test names(merged_frame) == [:t_done, :Sessions, :BounceRate] ∪ map(symbol, collect(keys(domain["custom_metrics"])))
@test size(merged_frame, 1) > 0


# TimerByMinute
for timer in mPulseAPI.supported_timers ∪ collect(keys(domain["custom_timers"]))
    tbm = mPulseAPI.getTimerByMinute(token, appID, timer=timer)

    @test size(tbm) == (1440, 3)
    @test names(tbm) == [:timestamp, symbol(timer), :moe]
end

@test_throws mPulseAPIRequestException mPulseAPI.getTimerByMinute(token, appID, timer="Some-Bad-Timer")
