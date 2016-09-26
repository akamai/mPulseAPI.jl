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


# Page Groups
page_groups = mPulseAPI.getPageGroupTimers(token, appID)

@test size(page_groups, 2) == 5
@test names(page_groups) == [:page_group, :t_done_median, :t_done_moe, :t_done_count, :t_done_total_pc]

page_groups = mPulseAPI.getPageGroupTimers(token, appID, friendly_names=true)

@test size(page_groups, 2) == 5
@test names(page_groups) == [symbol("Page Group"), symbol("Median Time (ms)"), symbol("MoE (ms)"), symbol("Measurements"), symbol("% of total")]
