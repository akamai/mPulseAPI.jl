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

if !isempty(mPulseAPIAlert)
    # Check alert
    alert = getRepositoryAlert(token, alertName=mPulseAPIAlert)
    @test !isempty(alert)
    @test alert["name"] == "mPulseAPI Test Alert"
    @test alert["tenantID"] == 236904
    @test alert["tenantID"] == tenant["id"]

    alerts = getRepositoryAlert(token)
    @test isa(alerts, Vector)
    @test mPulseAPIAlert ∈ map(x -> x["name"], alerts)
end

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

#### Dynamic Alerting ###
# Check alert
if !isempty(DA_mPulseAPIAlert)
    @testset "Dynamic Alerting" begin
        DAalert = getRepositoryAlert(token, alertName=DA_mPulseAPIAlert)
        @test !isempty(alert)
        @test DAalert["name"] == "mPulseAPI Dynamic Test Alert"
        @test DAalert["id"] == 2251091
        @test DAalert["tenantID"] == 236904
        @test DAalert["tenantID"] == tenant["id"]
        @test DAalert["attributes"]["dynamic"] == true
        @test DAalert["attributes"]["statisticalModelID"] == 415
        @test DAalert["attributes"]["state"] ∈ ["AutoCleared", "Updated", "Active", "ModelNotReady"]

        # Update alert via post request
        postRepositoryAlert(token, alertID = DAalert["id"], attributes = Dict("version" => 2))

        # Check statistical model
        statModel = getRepositoryStatModel(token, statModelID = DAalert["attributes"]["statisticalModelID"])
        @test !isempty(statModel)
        @test statModel["id"] == 415
        @test statModel["parentID"] == DAalert["id"]
        @test statModel["parentID"] == 2251091
        @test statModel["tenantID"] == tenant["id"]
        @test statModel["tenantID"] == 236904
        @test statModel["attributes"]["type"] == 1
        @test statModel["attributes"]["version"] == 1.0

        # Update statistical model via post request
        postRepositoryStatModel(token, statModelID = statModel["id"], attributes = Dict("type" => 1))
    end
end
