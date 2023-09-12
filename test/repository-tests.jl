# Try getting token
@test_throws ArgumentError getRepositoryToken(mPulseAPITenant)
token = getRepositoryToken(mPulseAPITenant, mPulseAPIToken)
@test !isempty(token)
token = getRepositoryToken(mPulseAPITenant)
@test !isempty(token)

# Get all domains
domains = getRepositoryDomain(token)
@test length(domains) == 2

domainNames = map(d -> d["name"], domains)
@test "mPulse Demo" ∈ domainNames
@test "mPulseAPI Test" ∈ domainNames

# Get a specific domain
appKey = filter(d -> d["name"] == "mPulseAPI Test", domains)[1]["attributes"]["appKey"]
@test !isempty(appKey)

domain = getRepositoryDomain(token, appKey=appKey)
@test !isempty(domain)

# Check domain parameters
@test domain["name"] == "mPulseAPI Test"
@test domain["attributes"]["appKey"] == appKey
@test domain["resource_timing"]

# Check custom metrics
@test isa(domain["custom_metrics"], Dict)
@test length(domain["custom_metrics"]) == 3

@test haskey(domain["custom_metrics"], "Conversion")
@test haskey(domain["custom_metrics"], "OrderTotal")
@test haskey(domain["custom_metrics"], "Revenue GBP")

@test domain["custom_metrics"]["Conversion"]["index"] == 0
@test domain["custom_metrics"]["Conversion"]["fieldname"] == "custommetric0"
@test domain["custom_metrics"]["Conversion"]["dataType"]["type"] == "Percentage"

@test domain["custom_metrics"]["Revenue GBP"]["index"] == 1
@test domain["custom_metrics"]["Revenue GBP"]["fieldname"] == "custommetric1"
@test domain["custom_metrics"]["Revenue GBP"]["dataType"]["type"] == "Currency"
@test domain["custom_metrics"]["Revenue GBP"]["dataType"]["currencyCode"] == "GBP"
# Bug in mPulseAPI means that `currencySymbol` will sometimes disappear
@test !haskey(domain["custom_metrics"]["Revenue GBP"]["dataType"], "currencySymbol") || domain["custom_metrics"]["Revenue GBP"]["dataType"]["currencySymbol"] == "£"
@test domain["custom_metrics"]["Revenue GBP"]["dataType"]["decimalPlaces"] == "2"

# CustomMetric2 is inactive

@test domain["custom_metrics"]["OrderTotal"]["index"] == 3
@test domain["custom_metrics"]["OrderTotal"]["fieldname"] == "custommetric3"
@test domain["custom_metrics"]["OrderTotal"]["dataType"]["type"] == "Currency"
@test domain["custom_metrics"]["OrderTotal"]["dataType"]["currencyCode"] == "USD"
@test domain["custom_metrics"]["OrderTotal"]["dataType"]["decimalPlaces"] == "2"

# Check custom timers
@test isa(domain["custom_timers"], Dict)
@test length(domain["custom_timers"]) == 1

@test haskey(domain["custom_timers"], "ResourceTimer")

@test domain["custom_timers"]["ResourceTimer"]["index"] == 0
@test domain["custom_timers"]["ResourceTimer"]["fieldname"] == "customtimer0"
@test domain["custom_timers"]["ResourceTimer"]["mpulseapiname"] == "CustomTimer0"

# Check tenant
tenant = getRepositoryTenant(token, name=mPulseAPITenant)
@test !isempty(tenant)
@test tenant["name"] == mPulseAPITenant

# Now check all exceptions
@test_throws ArgumentError getRepositoryToken("", "")

@test_throws mPulseAPIAuthException getRepositoryToken(mPulseAPITenant, "some-invalid-token")

@test_throws mPulseAPIAuthException getRepositoryDomain("some-invalid-token", appKey=appKey * "-" * string(round(Int, rand()*100000), base=16, pad=5))

@test_throws ArgumentError getRepositoryObject("", "", Dict{Symbol, Any}())
@test_throws ArgumentError getRepositoryObject("foo", "", Dict{Symbol, Any}())
@test_throws ArgumentError getRepositoryObject("foo", "tenant", Dict{Symbol, Any}())

@test_throws ArgumentError postRepositoryObject("", "", Dict{Symbol, Any}())
@test_throws ArgumentError postRepositoryObject("foo", "", Dict{Symbol, Any}())
@test_throws ArgumentError postRepositoryObject("foo", "tenant", Dict{Symbol, Any}())
@test_throws mPulseAPIAuthException postRepositoryObject("foo", "tenant", Dict{Symbol, Any}(:id => 1); filterRequired=false)
