using mPulseAPI
using Base.Test

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

include("repository-tests.jl")

include("query-tests.jl")
