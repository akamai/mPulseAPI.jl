# Exceptions


* [mPulseAPIException](exceptions.md#datatype-mpulseapiexception)
* [mPulseAPIAuthException](exceptions.md#datatype-mpulseapiauthexception)
* [mPulseAPIRequestException](exceptions.md#datatype-mpulseapirequestexception)
* [mPulseAPIResultFormatException](exceptions.md#datatype-mpulseapiresultformatexception)
* [mPulseAPIBugException](exceptions.md#datatype-mpulseapibugexception)
## Exported Types
### datatype `mPulseAPIException`
[exceptions.jl#24-30](https://github.com/akamai/mPulseAPI.jl/tree/master/src/exceptions.jl#L24-L30){: .source-link}

Thrown when the REST API has a problem and returns something other than a 2xx response.

#### Fields
`msg::AbstractString`
:    The error message

`response::Response`
:    The response object from the REST API call.  You can inspect headers, data, cookies, redirects, and the initiating request.

`responseBody::AbstractString`
:    The body of the HTTP response from the server


---

### datatype `mPulseAPIAuthException`
[exceptions.jl#46-52](https://github.com/akamai/mPulseAPI.jl/tree/master/src/exceptions.jl#L46-L52){: .source-link}

Thrown when the token used to authenticate with the REST API is invalid or has expired

#### Fields
`msg::AbstractString`
:    This message is always set to "Error Authenticating with REST API"

`response::Response`
:    The response object from the REST API call.  You can inspect headers, data, cookies, redirects, and the initiating request.

`responseBody::AbstractString`
:    The body of the HTTP response from the server


---

### datatype `mPulseAPIRequestException`
[exceptions.jl#74-80](https://github.com/akamai/mPulseAPI.jl/tree/master/src/exceptions.jl#L74-L80){: .source-link}

Thrown when a request parameter is invalid

#### Fields
`msg::AbstractString`
:    The error message sent from the mPulse server

`code::AbstractString`
:    The error code sent from the mPulse server

`parameter::AbstractString`
:    The parameter that the mPulse server had a problem with

`value::AbstractString`
:    The value of the parameter that the mPulse server had a problem with

`response::Response`
:    The response object from the REST API call.  You can inspect headers, data, cookies, redirects, and the initiating request.


---

### datatype `mPulseAPIResultFormatException`
[exceptions.jl#93-96](https://github.com/akamai/mPulseAPI.jl/tree/master/src/exceptions.jl#L93-L96){: .source-link}

Thrown when the result returned by an API call was not in the expected format

#### Fields
`msg::AbstractString`
:    The error message

`data::Any`
:    The actual data returned


---

### datatype `mPulseAPIBugException`
[exceptions.jl#112-118](https://github.com/akamai/mPulseAPI.jl/tree/master/src/exceptions.jl#L112-L118){: .source-link}

Thrown when the REST API has an internal server error and returns a `500 Internal Server Error`

#### Fields
`msg::AbstractString`
:    The string "Internal Server Error, please report this. Timestamp: <current unix timestamp in seconds since the epoch>"

`response::Response`
:    The response object from the REST API call.  You can inspect headers, data, cookies, redirects, and the initiating request.

`responseBody::AbstractString`
:    The body of the HTTP response from the server


---

