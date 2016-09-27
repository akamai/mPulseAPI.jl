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
        println("mPulseAPI.$method")
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
        println("mPulseAPI.getMetricsByTimension:$dimension")
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
