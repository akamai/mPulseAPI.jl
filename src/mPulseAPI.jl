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
"""
$(readall(joinpath(dirname(dirname(@__FILE__)), "README.md")))
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

include(joinpath(dirname(@__FILE__), "exceptions.jl"))
include(joinpath(dirname(@__FILE__), "cache.jl"))

end
