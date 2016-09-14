export
    mPulseAPIException,
    mPulseAPIAuthException,
    mPulseAPIRequestException,
    mPulseAPIResultFormatException

import HttpCommon.Response

"""
Thrown when the REST API has a problem and returns something other than a 2xx response.

* `msg::AbstractString`  The error message
* `response::Response`   The response object from the REST API call.  You can inspect headers, data, cookies, redirects, and the initiating request.
"""
immutable mPulseAPIException <: Exception
    msg::AbstractString
    response::Response
end

"""
Thrown when the token used to authenticate with the REST API is invalid or has expired

* `response::Response`  The response object from the REST API call.  You can inspect headers, data, cookies, redirects, and the initiating request.
"""
immutable mPulseAPIAuthException <: Exception
    response::Response
end

"""
Thrown when a request parameter is invalid

* `msg::AbstractString`         The error message sent from the mPulse server
* `code::AbstractString`        The error code sent from the mPulse server
* `parameter::AbstractString`   The parameter that the mPulse server had a problem with
* `value::AbstractString`       The value of the parameter that the mPulse server had a problem with
* `response::Response`          The response object from the REST API call.  You can inspect headers, data, cookies, redirects, and the initiating request.
"""
immutable mPulseAPIRequestException <: Exception
    msg::AbstractString
    code::AbstractString
    parameter::AbstractString
    value::AbstractString
    response::Union{Response, Void}
end

"""
Thrown when the result returned by an API call was not in the expected format

* `msg::AbstractString` The error message
* `data::Any`           The actual data returned
"""
immutable mPulseAPIResultFormatException <: Exception
    msg::AbstractString
    data::Any
end
