mPulseAPIToken  = ENV["mPulseAPIToken"]
mPulseAPITenant = ENV["mPulseAPITenant"]

# Check environment
@test !isempty(mPulseAPIToken)
@test !isempty(mPulseAPITenant)

# Try getting token
token = getRepositoryToken(mPulseAPITenant, mPulseAPIToken)
@test !isempty(token)

# Get all domains
domains = getRepositoryDomain(token)
@test length(domains) == 1

# Get a specific domain
appID = domains[1]["attributes"]["appID"]
@test !isempty(appID)

domain = getRepositoryDomain(token, appID=appID)
@test !isempty(domain)

# Check domain parameters
@test domain["name"] == "mPulse Demo"
@test domain["attributes"]["appID"] == appID
@test domain["resource_timing"]

# Check custom metrics
@test isa(domain["custom_metrics"], Dict)
@test length(domain["custom_metrics"]) == 2

@test haskey(domain["custom_metrics"], "Conversion")
@test haskey(domain["custom_metrics"], "OrderTotal")

@test domain["custom_metrics"]["Conversion"]["index"] == 0
@test domain["custom_metrics"]["Conversion"]["fieldname"] == "custom_metrics_0"
@test domain["custom_metrics"]["Conversion"]["dataType"]["type"] == "Percentage"

# CustomMetric1 does not exist
# CustomMetric2 is inactive

@test domain["custom_metrics"]["OrderTotal"]["index"] == 3
@test domain["custom_metrics"]["OrderTotal"]["fieldname"] == "custom_metrics_3"
@test domain["custom_metrics"]["OrderTotal"]["dataType"]["type"] == "Currency"
@test domain["custom_metrics"]["OrderTotal"]["dataType"]["currencyCode"] == "USD"
@test domain["custom_metrics"]["OrderTotal"]["dataType"]["decimalPlaces"] == "2"

# Check custom timers
@test isa(domain["custom_timers"], Dict)
@test length(domain["custom_timers"]) == 1

@test haskey(domain["custom_timers"], "ResourceTimer")

@test domain["custom_timers"]["ResourceTimer"]["index"] == 0
@test domain["custom_timers"]["ResourceTimer"]["fieldname"] == "timers_custom0"
@test domain["custom_timers"]["ResourceTimer"]["mpulseapiname"] == "CustomTimer0"

# Check tenant
tenant = getRepositoryTenant(token, name=mPulseAPITenant)
@test !isempty(tenant)
@test tenant["name"] == mPulseAPITenant


# Now check all exceptions
@test_throws ArgumentError getRepositoryToken("", "")

@test_throws mPulseAPIAuthException getRepositoryToken(mPulseAPITenant, "some-invalid-token")
