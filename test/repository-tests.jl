# Try getting token
token = getRepositoryToken(mPulseAPITenant, mPulseAPIToken)
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

# Check alert
alert = getRepositoryAlert(token, alertName=mPulseAPIAlert)
@test !isempty(alert)
@test alert["name"] == "mPulseAPI Test Alert"
@test alert["tenantID"] == 236904
@test alert["tenantID"] == tenant["id"]

# Now check all exceptions
@test_throws ArgumentError getRepositoryToken("", "")

@test_throws mPulseAPIAuthException getRepositoryToken(mPulseAPITenant, "some-invalid-token")

try
    getRepositoryDomain("some-invalid-token", appKey=appKey * "-" * base(16, round(Int, rand()*100000), 5))
catch ex
    if isa(ex, mPulseAPIBugException)
        warn("Expected mPulseAPIAuthException, got mPulseAPIBugException", ex)
    else
        @test isa(ex, mPulseAPIAuthException) || isa(ex, mPulseAPIBugException)
    end
end


#### Dynamic Alerting ###
# Try getting token
token = getRepositoryToken(DA_mPulseAPITenant, DA_mPulseAPIToken)
@test !isempty(token)

# Check tenant
tenant = getRepositoryTenant(token, name=DA_mPulseAPITenant)
@test !isempty(tenant)
@test tenant["name"] == "SOASTA_Users"

# Check alert
DAalert = getRepositoryAlert(token, alertName=DA_mPulseAPIAlert)
@test !isempty(alert)
@test DAalert["name"] == "mPulseAPI Dynamic Test Alert"
@test DAalert["id"] == 34607825
@test DAalert["tenantID"] == 1
@test DAalert["tenantID"] == tenant["id"]
@test DAalert["attributes"]["dynamic"] == true
@test DAalert["attributes"]["statisticalModelID"] == 11204

# Check statistical model
statModel = getRepositoryStatModel(token, statModelID = 11204)
@test !isempty(statModel)
@test statModel["id"] == 11204
@test statModel["parentID"] == 34607825
@test statModel["tenantID"] == 1
@test statModel["tenantID"] == tenant["id"]
