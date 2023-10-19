using mPulseAPI
using Test, Dates

# Check environment
if !haskey(ENV, "mPulseAPIToken")
    println("Set the `mPulseAPIToken' environment variable to run tests.  See https://soasta.github.io/mPulseAPI.jl/apiToken/index.html for details on how to get a token.")
    exit(-2)
end

if !haskey(ENV, "mPulseAPITenant")
    println("Set the `mPulseAPITenant' environment variable to run tests against your specific mPulse tenant.")
    exit(-3)
end

mPulseAPIToken  = ENV["mPulseAPIToken"]
mPulseAPITenant = ENV["mPulseAPITenant"]
mPulseAPIAlert  = get(ENV, "mPulseAPIAlert", "")

DA_mPulseAPIAlert  = get(ENV, "DA_mPulseAPIAlert", "")

verbosity = (get(ENV, "mPulseAPIVerbose", "false") == "true")

endpoint = get(ENV, "mPulseAPIEndpoint", "")

if !isempty(endpoint)
    mPulseAPI.setEndpoints(endpoint)
end

mPulseAPI.setVerbose(verbosity)

t_start = Int(datetime2unix(now())*1000)

@testset "mPulseAPI" begin
    @testset "Repository" begin
        include("repository-tests.jl")
    end

    @testset "Alerts" begin
        include("alert-tests.jl")
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
