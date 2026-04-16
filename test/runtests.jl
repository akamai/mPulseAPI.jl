using mPulseAPI
using Test, Dates, DataFrames, HTTP, LightXML, TimeZones

mPulseAPIToken  = get(ENV, "mPulseAPIToken", "")
mPulseAPITenant = get(ENV, "mPulseAPITenant", "")
mPulseAPIAlert  = get(ENV, "mPulseAPIAlert", "")

DA_mPulseAPIAlert = get(ENV, "DA_mPulseAPIAlert", "")

verbosity = (get(ENV, "mPulseAPIVerbose", "false") == "true")

endpoint = get(ENV, "mPulseAPIEndpoint", "")

if !isempty(endpoint)
    mPulseAPI.setEndpoints(endpoint)
end

mPulseAPI.setVerbose(verbosity)

t_start = mPulseAPI._to_epoch_ms(now())

@testset "mPulseAPI" begin

    @testset "XML Utilities" begin
        include("xml-utility-tests.jl")
    end

    if isempty(mPulseAPIToken)
        println("Set the `mPulseAPIToken' environment variable to run tests.  See https://soasta.github.io/mPulseAPI.jl/apiToken/index.html for details on how to get a token.")
        @warn "Skipping live integration tests: mPulseAPIToken not set"
    elseif isempty(mPulseAPITenant)
        println("Set the `mPulseAPITenant' environment variable to run tests against your specific mPulse tenant.")
        @warn "Skipping live integration tests: mPulseAPITenant not set"
    else
        @testset "Repository" begin
            include("repository-tests.jl")
        end

        @testset "Alerts" begin
            include("alert-tests.jl")
        end

        @testset "Annotations" begin
            include("annotation-tests.jl")
        end

        @testset "Query" begin
            include("query-tests.jl")
        end

        @testset "Beacons" begin
            include("beacon-api.jl")
        end

        @testset "Change URL" begin
            include("zzz_change-url-tests.jl")
        end
    end

    # Mocked testset runs last: it installs global HTTP.get/HTTP.post overloads
    # that must not affect the live integration tests above.
    @testset "Mocked" begin
        include("mock-tests.jl")
    end

end
