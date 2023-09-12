token  = getRepositoryToken(mPulseAPITenant, mPulseAPIToken)

if !isempty(mPulseAPIAlert)
    # Check alert
    alert = getRepositoryAlert(token, alertName=mPulseAPIAlert)
    @test !isempty(alert)
    @test alert["name"] == mPulseAPIAlert
    @test alert["tenantID"] == 236904

    alerts = getRepositoryAlert(token)
    @test isa(alerts, Vector)
    @test mPulseAPIAlert ∈ map(x -> x["name"], alerts)
    @test mPulseAPI.clearAlertCache(; alertName=mPulseAPIAlert)

    @test_throws mPulseAPIException deleteRepositoryAlert(token; alertID=1000)
end


#### Dynamic Alerting ###
# Check alert
if !isempty(DA_mPulseAPIAlert)
    @testset "Dynamic Alerting" begin
        DAalert = getRepositoryAlert(token, alertName=DA_mPulseAPIAlert)
        @test !isempty(DAalert)
        @test DAalert["name"] == DA_mPulseAPIAlert
        @test DAalert["id"] == 2251091
        @test DAalert["tenantID"] == 236904
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
        @test statModel["tenantID"] == 236904
        @test statModel["attributes"]["type"] == 1
        @test statModel["attributes"]["version"] == 1.0

        # Update statistical model via post request
        postRepositoryStatModel(token, statModelID = statModel["id"], attributes = Dict("type" => 1))

        @test mPulseAPI.clearStatModelCache(; statModelID=statModel["id"])
    end
end
