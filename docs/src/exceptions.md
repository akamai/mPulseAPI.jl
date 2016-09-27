# Exceptions


* [mPulseAPIException](exceptions.md#datatype-mpulseapiexception)
* [mPulseAPIAuthException](exceptions.md#datatype-mpulseapiauthexception)
* [mPulseAPIRequestException](exceptions.md#datatype-mpulseapirequestexception)
* [mPulseAPIResultFormatException](exceptions.md#datatype-mpulseapiresultformatexception)
## Exported Types
[exceptions.jl#20-23](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/exceptions.jl#L20-L23){: .source-link style="float:right;font-size:0.8em;"}
### datatype `mPulseAPIException`

Thrown when the REST API has a problem and returns something other than a 2xx response.

#### Fields
`msg::AbstractString`
:    The error message

`response::Response`
:    The response object from the REST API call.  You can inspect headers, data, cookies, redirects, and the initiating request.


---

[exceptions.jl#33-35](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/exceptions.jl#L33-L35){: .source-link style="float:right;font-size:0.8em;"}
### datatype `mPulseAPIAuthException`

Thrown when the token used to authenticate with the REST API is invalid or has expired

#### Fields
`response::Response`
:    The response object from the REST API call.  You can inspect headers, data, cookies, redirects, and the initiating request.


---

[exceptions.jl#57-63](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/exceptions.jl#L57-L63){: .source-link style="float:right;font-size:0.8em;"}
### datatype `mPulseAPIRequestException`

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

[exceptions.jl#76-79](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/exceptions.jl#L76-L79){: .source-link style="float:right;font-size:0.8em;"}
### datatype `mPulseAPIResultFormatException`

Thrown when the result returned by an API call was not in the expected format

#### Fields
`msg::AbstractString`
:    The error message

`data::Any`
:    The actual data returned


---

