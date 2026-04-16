###################################################
#
# Copyright Akamai, Inc.
# Distributed under the terms of the MIT license
#
# File: Annotation.jl
#
# Functions to communicate with the mPulse Annotations REST API.
# This file MUST be `include()`d from `mPulseAPI.jl`
#
###################################################

export getAnnotation, getAnnotations

"""
Fetches a single annotation from the mPulse annotations API by ID.

### Arguments
`token::AbstractString`
:    The X-Auth-Token fetched by calling [`getRepositoryToken`](@ref)

`annotationID::Int64`
:    The ID of the annotation to fetch.

### Returns
`Dict{String, Any}` — The annotation object returned by the mPulse annotations API.

The annotation `Dict` typically contains:

`id::Int`
:    Unique annotation ID

`title::AbstractString`
:    Short description of the annotation (usually the alert name)

`start::Int`
:    Annotation start time as epoch milliseconds

`end::Int`
:    Annotation end time as epoch milliseconds

`domainID::Int`
:    The domain ID this annotation belongs to

Additional fields may be present depending on the mPulse API version.

### Throws
`ArgumentError`
:    If `token` is empty or `annotationID` is not positive

`mPulseAPIAuthException`
:    If the token is invalid or has expired (HTTP 401)

`mPulseAPIBugException`
:    If the API returns an HTTP 500 (server-side bug)

`mPulseAPIException`
:    If the API returns an unexpected error response
"""
function getAnnotation(token::AbstractString, annotationID::Int64)
    global verbose

    _validate_annotation_token(token)

    if annotationID <= 0
        throw(ArgumentError("`annotationID' must be a positive integer"))
    end

    url = AnnotationsEndpoint * "/$(annotationID)"

    if verbose
        println("GET $url")
        println("X-Auth-Token: $token")
    end

    resp = HTTP.get(url,
                    Dict("X-Auth-Token" => token),
                    status_exception = false)

    _check_annotation_response(resp, "Error fetching annotation $(annotationID)")

    return JSON.parse(String(resp.body))
end


"""
Fetches annotations from the mPulse annotations API for a given domain and optional time range.

Annotations are written by the mPulse real-time alerting system when an anomaly is detected
or cleared, and can be used to accurately reconstruct alert history for a domain without
re-running the detection model locally.

### Arguments
`token::AbstractString`
:    The X-Auth-Token fetched by calling [`getRepositoryToken`](@ref)

### Keyword Arguments
`domainID::Union{Int64, Nothing}`
:    The ID of the app/domain to fetch annotations for. If omitted or `nothing`,
     returns all annotations for the authenticated tenant.

`dateStart::Union{DateTime, ZonedDateTime, Nothing}`
:    Start of the time range (inclusive). Converted to epoch milliseconds internally.
     Optional; omit to fetch annotations from the earliest available time.

`dateEnd::Union{DateTime, ZonedDateTime, Nothing}`
:    End of the time range (inclusive). Converted to epoch milliseconds internally.
     Optional; omit to fetch annotations up to the current time.

### Returns
`Vector` — Array of annotation dicts returned by the mPulse annotations API. Each element is
typically a `Dict{String, Any}`, but the exact element type reflects the raw `JSON.parse` output.

Each annotation `Dict` typically contains:

`id::Int`
:    Unique annotation ID

`title::AbstractString`
:    Short description of the annotation (usually the alert name)

`start::Int`
:    Annotation start time as epoch milliseconds

`end::Int`
:    Annotation end time as epoch milliseconds

`domainID::Int`
:    The domain ID this annotation belongs to

Additional fields may be present depending on the mPulse API version.

### Throws
`ArgumentError`
:    If `token` is empty

`mPulseAPIAuthException`
:    If the token is invalid or has expired (HTTP 401)

`mPulseAPIBugException`
:    If the API returns an HTTP 500 (server-side bug)

`mPulseAPIException`
:    If the API returns an unexpected error response

`mPulseAPIResultFormatException`
:    If the API response is not in the expected format
"""
function getAnnotations(token::AbstractString;
                        domainID::Union{Int64, Nothing}                = nothing,
                        dateStart::Union{DateTime, ZonedDateTime, Nothing} = nothing,
                        dateEnd::Union{DateTime, ZonedDateTime, Nothing}   = nothing)

    global verbose

    _validate_annotation_token(token)

    query = Dict{String, Any}()

    if !isnothing(domainID)
        query["domain"] = domainID
    end

    if !isnothing(dateStart)
        query["date-start"] = _to_epoch_ms(dateStart)
    end

    if !isnothing(dateEnd)
        query["date-end"] = _to_epoch_ms(dateEnd)
    end

    if verbose
        println("GET $AnnotationsEndpoint")
        println("X-Auth-Token: $token")
        println(query)
    end

    resp = HTTP.get(AnnotationsEndpoint,
                    Dict("X-Auth-Token" => token),
                    query            = query,
                    status_exception = false)

    _check_annotation_response(resp, "Error fetching annotations")

    result = JSON.parse(String(resp.body))

    # The API may return an array directly or a wrapped object {"annotations": [...]}
    if isa(result, AbstractArray)
        return result
    elseif isa(result, AbstractDict) && haskey(result, "annotations")
        return result["annotations"]
    else
        throw(mPulseAPIResultFormatException("Unexpected annotations response format", result))
    end
end


# Validate that the auth token is non-empty
function _validate_annotation_token(token::AbstractString)
    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end
end

# Translate HTTP response status to the appropriate mPulseAPI exception
function _check_annotation_response(resp, error_msg::AbstractString)
    if resp.status == 401
        throw(mPulseAPIAuthException(resp))
    elseif resp.status == 500
        throw(mPulseAPIBugException(resp))
    elseif resp.status != 200
        throw(mPulseAPIException(error_msg, resp))
    end
end
