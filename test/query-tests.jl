mPulseAPIToken  = ENV["mPulseAPIToken"]
mPulseAPITenant = ENV["mPulseAPITenant"]

token  = getRepositoryToken(mPulseAPITenant, mPulseAPIToken)
domain = getRepositoryDomain(token, appName="mPulse Demo")
appID  = domain["attributes"]["appID"]

# Summary
@test_throws mPulseAPIAuthException mPulseAPI.getSummaryTimers("invalid-token", appID)
@test_throws mPulseAPIRequestException mPulseAPI.getSummaryTimers(token, appID, filters = Dict("invalid-token" => "foo"))

summary = mPulseAPI.getSummaryTimers(token, appID)

@test length(summary) == 5

@test isa(summary["n"], Int)
@test isa(summary["median"], Int)
@test isa(summary["p95"], Int)
@test isa(summary["p98"], Int)
@test isa(summary["moe"], Float64)


function testDimensionTable(method, first_symbol, first_friendly)
    println(method)

    x = getfield(mPulseAPI, method)(token, appID)

    @test size(x, 2) == 5
    @test names(x) == [first_symbol, :t_done_median, :t_done_moe, :t_done_count, :t_done_total_pc]

    x = getfield(mPulseAPI, method)(token, appID, friendly_names=true)
    @test size(x, 2) == 5
    @test names(x) == [symbol(first_friendly), symbol("Median Time (ms)"), symbol("MoE (ms)"), symbol("Measurements"), symbol("% of total")]
end

# Page Groups
testDimensionTable(:getPageGroupTimers, :page_group, "Page Group")

# Browsers
testDimensionTable(:getBrowserTimers, :user_agent, "User Agent")

# ABTests
testDimensionTable(:getABTestTimers, :test_name, "Test Name")

