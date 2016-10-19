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

if VERSION >= v"0.4"
    __precompile__(true)
end

module mPulseAPI
# This should bind at compile time, so @__FILE__ is set to mPulseAPI.jl
const __module_dir = dirname(dirname(@__FILE__))

"""
$(replace(readall(joinpath(mPulseAPI.__module_dir, "README.md")), r"\n.*travis-ci\.org.*\n", ""))
"""
mPulseAPI

if VERSION >= v"0.4"
    using Base.Dates
    import Base: @__doc__
else
    using Dates
    macro __doc__(ex)
        esc(ex)
    end
end

using Requests, LightXML, HttpCommon

# Tells docgen.jl to document internal methods as well
const __document_internal = true

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
    data = chomp( readall( joinpath(mPulseAPI.__module_dir, "doc-snippets", name * ".md") ) )

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
            data = format(data, replacers...)
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
