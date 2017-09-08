###################################################
#
# Copyright 2016 SOASTA, Inc.
# Distributed under the terms of the MIT license
#
# File: mPulseAPI.jl
#
# Functions to communicate with the mPulse Query and Repository REST APIs
#
###################################################

__precompile__(true)

module mPulseAPI
# This should bind at compile time, so @__FILE__ is set to mPulseAPI.jl
const __module_dir = dirname(dirname(@__FILE__))

function readdoc(path::AbstractString...)
    docpath = joinpath(mPulseAPI.__module_dir, path...)
    if VERSION < v"0.5"
        return readall(docpath)
    elseif VERSION < v"0.7"
        return readstring(docpath)
    else
        return read(docpath, AbstractString)
    end
end

"""
$(replace(mPulseAPI.readdoc("README.md"), r"\n.*travis-ci\.org.*\n", ""))
"""
mPulseAPI

using Base.Dates
import Base: @__doc__

using Requests, LightXML, HttpCommon, Formatting

# Tells docgen.jl to document internal methods as well
const __document_internal = true

const default_SOASTAEndpoint = "https://mpulse.soasta.com/concerto"

function __init__()
    setEndpoints()

    global verbose = false
end

"""
Change the SOASTA API endpoint that we connect to.  The default is `$(mPulseAPI.default_SOASTAEndpoint)`

#### Example

```julia
mPulseAPI.setEndpoints("https://mpulse-alt.soasta.com/concerto")
```
"""
function setEndpoints(SOASTAEndpoint::AbstractString = default_SOASTAEndpoint)
    global mPulseEndpoint     = "$SOASTAEndpoint/mpulse/api/v2/"
    global RepositoryEndpoint = "$SOASTAEndpoint/services/rest"
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
    date = replace(date, r"(?:Z|\+[\d:]+)(\s|$)", "")
    return DateTime(date)
end

# Fix datatype of elements got from JSON because the mPulse API is bad in what it sends
function fixJSONDataType(value::Union{AbstractString, Void})
    if value == nothing || isa(value, Void)
        # nothing
    elseif value == "null"
        value = nothing
    elseif value == "true"
        value = true
    elseif value == "false"
        value = false
    elseif ismatch(r"^-?\d+$", value)
        value = parse(Int, value, 10)
    elseif ismatch(r"^-?\d+\.\d+$", value)
        value = parse(Float64, value)
    end

    return value
end

function readdocs(name::AbstractString, replacers=[]; indent=0)
    # read the file and strip out the newline at the end
    data = chomp( readdoc( "doc-snippets", name * ".md" ) )

    # If any placeholders have default values, pull them out and insert them into the replace
    # array if a value is not already set
    while( (defaults = match(r"\{(\d+)=(.*?)\}", data)) != nothing)
        id      = parse(Int, defaults.captures[1])
        default = defaults.captures[2]

        data = replace(data, Regex("\\{$id=(.*?)\\}"), "{$id}")

        if length(replacers) < id
            resize!(replacers, id)
            replacers[id] = default
        end
    end

    if length(replacers) > 0
        # If we have replacers, then replace all non-placeholders braces with {{}}
        data = replace(data, r"(\{[A-Za-z][\w,|]+\})", s"{\1}")

        # And run the whole thing through format
        try
            data = Formatting.format(data, replacers...)
        catch
            println(replacers)
            println(data)
            rethrow()
        end
    end

    if indent > 0
        data = replace(data, r"^"m, repeat(" ", indent))
    end

    return data
end

include(joinpath(dirname(@__FILE__), "exceptions.jl"))
include(joinpath(dirname(@__FILE__), "cache_utilities.jl"))

include(joinpath(dirname(@__FILE__), "RepositoryAPI.jl"))
include(joinpath(dirname(@__FILE__), "QueryAPI.jl"))

end
