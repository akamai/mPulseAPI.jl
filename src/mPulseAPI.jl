###################################################
#
# Copyright Akamai, Inc.
# Distributed under the terms of the MIT license
#
# File: mPulseAPI.jl
#
# Functions to communicate with the mPulse Query and Repository REST APIs
#
###################################################
"""
$(replace(readchomp(joinpath(dirname(@__DIR__), "README.md")), "/docs/src/" => ""))
"""
module mPulseAPI

using Dates

using LightXML, Format, TimeZones, DataFrames
import HTTP
export LightXML

const default_mPulseEndpoint = "https://mpulse.soasta.com/concerto"

function __init__()
    setEndpoints()

    global verbose = false
end

"""
Change the mPulse API endpoint that we connect to.  The default is `$(mPulseAPI.default_mPulseEndpoint)`

### Example
```julia
mPulseAPI.setEndpoints("https://mpulse-alt.soasta.com/concerto")
```
"""
function setEndpoints(APIEndpoint::AbstractString = default_mPulseEndpoint)
    global mPulseEndpoint     = "$APIEndpoint/mpulse/api/v2/"
    global RepositoryEndpoint = "$APIEndpoint/services/rest"
    global RepositoryService  = "$RepositoryEndpoint/RepositoryService/v1"
    global TokenEndpoint      = "$RepositoryService/Tokens"
    global ObjectEndpoint     = "$RepositoryService/Objects"

    return (mPulseEndpoint, RepositoryService)
end


"""
Set verbosity of API calls.

If set to true, all URLs, headers and POST data will be printed to the console before making an API call.
"""
function setVerbose(vbs::Bool)
    global verbose = vbs
end

# Convenience method because the mPulse API is bad with dates
function iso8601ToDateTime(date::AbstractString)
    date = replace(date, r"(?:Z|\+[\d:]+)(\s|$)" => "")
    return DateTime(date)
end

# Internal convenience function for retrieving object info. Mainly used before updating or deleting an object.
function getObjectInfo(token::AbstractString, objectType::AbstractString, objectID::Int64, name::AbstractString)

    if objectType == "alert"
        object = getRepositoryAlert(token, alertID=objectID, alertName = name)
    elseif objectType == "domain"
        object = getRepositoryDomain(token, domainID=objectID, appName = name)
    elseif objectType == "tenant"
        object = getRepositoryTenant(token, tenantID=objectID, name = name)
    elseif objectType == "statisticalmodel"
        object = getRepositoryStatModel(token, statModelID=objectID, statModelName = name)
    else
        throw(ArgumentError("Unknown objectType `$(objectType)'"))
    end

    return object
end


# Fix datatype of elements got from JSON because the mPulse API is bad in what it sends
function fixJSONDataType(value::Union{AbstractString, Nothing})
    if value == nothing || isa(value, Nothing)
        # nothing
    elseif value == "null"
        value = nothing
    elseif value == "true"
        value = true
    elseif value == "false"
        value = false
    elseif occursin(r"^-?\d+$", value)
        value = parse(Int, value, base=10)
    elseif occursin(r"^-?\d+\.\d+$", value)
        value = parse(Float64, value)
    end

    return value
end

function readdocs(name::AbstractString, replacers=[]; indent=0)
    # read the file and strip out the newline at the end
    data = readchomp( joinpath(dirname(@__DIR__), "doc-snippets", name * ".md") )

    # If any placeholders have default values, pull them out and insert them into the replace
    # array if a value is not already set
    while( (defaults = match(r"\{(\d+)=(.*?)\}", data)) != nothing)
        id      = parse(Int, defaults.captures[1], base=10)
        default = defaults.captures[2]

        data = replace(data, Regex("\\{$id=(.*?)\\}") => "{$id}")

        if length(replacers) < id
            resize!(replacers, id)
            replacers[id] = default
        end
    end

    if length(replacers) > 0
        # If we have replacers, then replace all non-placeholders braces with {{}}
        data = replace(data, r"(\{[A-Za-z][\w,|]+\})" => s"{\1}")

        # And run the whole thing through format
        try
            data = Format.format(data, replacers...)
        catch
            @warn replacers
            @warn data
            rethrow()
        end
    end

    if indent > 0
        data = replace(data, r"^"m => repeat(" ", indent))
    end

    return data
end

include(joinpath(@__DIR__, "exceptions.jl"))
include(joinpath(@__DIR__, "cache_utilities.jl"))
include(joinpath(@__DIR__, "xml_utilities.jl"))

include(joinpath(@__DIR__, "RepositoryAPI.jl"))
include(joinpath(@__DIR__, "StatisticalModel.jl"))
include(joinpath(@__DIR__, "Alert.jl"))
include(joinpath(@__DIR__, "Domain.jl"))
include(joinpath(@__DIR__, "Tenant.jl"))
include(joinpath(@__DIR__, "Token.jl"))
include(joinpath(@__DIR__, "QueryAPI.jl"))

include(joinpath(@__DIR__, "BeaconAPI.jl"))

end
