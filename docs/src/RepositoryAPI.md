# Repository API


## Exported Functions
[RepositoryAPI.jl#56-100](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/RepositoryAPI.jl#L56-L100){: .source-link style="float:right;font-size:0.8em;"}
### function `getRepositoryToken`

Logs in to the mPulse repository and fetches an Authorization token that can be used for other calls

The token will be cached in memory for 5 hours, so subsequent calls using the same tenant will return
quickly without calling out to the API.  This can be a problem if the account has signed in from a different
location or is logged out of mPulse.  You can clear the cache for this token using `mPulseAPI.clearTokenCache(tenant)`

#### Arguments
`tenant::AbstractString`
:    The name of the tenant to log in to. The token will be bound to this tenant.

`apiToken::AbstractString`
:    The apiToken issued by mPulse that allows authenticating with the API. If you've
     previously authenticated with this tenant, the `apiToken` will be cached and does
     not need to be passed in again

#### Returns
`{ASCIIString}` The mPulse Repository Auth token which may be used in the `X-Auth-Token` header for subsequent API calls

#### Throws
`ArgumentError`
:    if the tenant or apiToken are empty

`mPulseAPIAuthException`
:    if authentication failed for some reason

---

[RepositoryAPI.jl#189-237](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/RepositoryAPI.jl#L189-L237){: .source-link style="float:right;font-size:0.8em;"}
### function `getRepositoryDomain`

Fetches a Domain object from the mPulse repository

To fetch a single domain, at least one of `domainID`, `appID` or `appName` must be passed in to identify the domain.
If none of these are passed in, then all domains that are readable by the specified `token` will be returned as an array.

The domain will be cached in memory for 1 hour, so subsequent calls using a matching `domainID`, `appID` or `appName` return
quickly without calling out to the API.  This can be a problem if the domain changes in the repository.
You can clear the cache for this domain using `mPulseAPI.clearDomainCache()` and passing in one of `domainID`, `appID` or `appName`.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling `mPulseAPI.getRepositoryToken`

#### Optional Arguments
`domainID::Int64`
:    The ID of the domain to fetch.  This is the fastest method, but it can be hard to figure out a domain's ID

`appID::AbstractString`
:    The App ID (formerly known as API key) associated with the domain.  This is available from the mPulse domain configuration dialog.

`appName::AbstractString`
:    The App name in mPulse. This is available from the mPulse domain configuration dialog.

#### Returns
`{Dict|Array{Dict}}` If one of `domainID`, `appID` or `appName` are passed in, then a single `domain` object is returned as a `Dict`.

If none of these are passed in, then an array of all domains is returned, each is a `Dict`.

The `domain` `Dict` has the following fields:

`name`
:    The app's name

`id::Int64`
:    The app's ID

`body::XMLElement`
:    An XML object representing the app's XML definition

`tenantID::Int64`
:    The ID of the tenant that this app is in

`description::AbstractString`
:    The description of this app entered into mPulse

`created::DateTime`
:    The timestamp when this object was created

`lastModified::DateTime`
:    The timestamp when this object was created

`attributes::Dict`
:    A `Dict` of attributes for this app, including its `AppID`

`custom_metrics::Dict`
:    A      `{Dict}` of Custom Metric names mapped to RedShift fieldnames with the following structure:
     
          Dict(
              <metric name> => Dict(
                  "index"        => <index>,                          # Numeric index
                  "fieldname"    => "custom_metrics_<index>",     # Field name in dswb tables
                  "lastModified" => <lastModifiedDate>,
                  "description"  => "<description>",
                  "dataType"     => Dict(
                      "decimalPlaces"  => "2",
                      "type"           => "<metric type>",
                      "currencySymbol" => "<symbol if this is a currency type>"
                  ),
                  "colors"       => [<array of color HEX codes>]
              ),
              ...
          )


`custom_timers::Dict`
:    A      `{Dict}` of Custom Timer names mapped to RedShift fieldnames with the following structure:
     
          Dict(
              <timer name> => Dict(
                  "index"         => <index>,                      # Numeric index
                  "fieldname"     => "timers_custom<index>",       # Field name in dswb tables
                  "mpulseapiname" => "CustomTimer<index>",
                  "lastModified"  => <lastModifiedDate>,
                  "description"   => "<description>",
                  "colors"        => Array(
                      Dict(
                          "timingType"  => "<seconds | milliseconds>",
                          "timingStart" => "<start timer value for this colour range>",
                          "timingEnd"   => "<end timer value for this colour range>",
                          "colorStart"  => "<start of this color range>",
                          "endStart"    => "<end of this color range>"
                      ),
                      ...
                  )
              ),
              ...
          )


`session_timeout::Int64`
:    The session timeout value in minutes

`resource_timing::Bool`
:    Flag indicating whether resource timing collection is enabled or not

`vertical_market::AbstractString`
:    The vertical market that this domain belongs to


#### Throws
`ArgumentError`
:    if token is empty or domainID, appID and appName are all empty

`mPulseAPIException`
:    if API access failed for some reason

`Exception`
:    if something unexpected happened while parsing the repository object


---

[RepositoryAPI.jl#307-329](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/RepositoryAPI.jl#L307-L329){: .source-link style="float:right;font-size:0.8em;"}
### function `getRepositoryTenant`

Fetches a Tenant object from the mPulse repository

At least one of `tenantID` or `name` must be passed in to identify the tenant.

The tenant will be cached in memory for 1 hour, so subsequent calls using a matching `tenantID`, or `name` return
quickly without calling out to the API.  This can be a problem if the tenant changes in the repository.
You can clear the cache for this tenant using `mPulseAPI.clearTenantCache()` and passing in one of `tenantID` or `name`.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling `mPulseAPI.getRepositoryToken`

#### Optional Arguments
`tenantID::Int64`
:    The ID of the tenant to fetch.  This is the fastest method, but it can be hard to figure out a tenant's ID

`name::AbstractString`
:    The Tenant name in mPulse.  This is available from the mPulse tenant list.

#### Returns
`{Dict}` The `tenant` object with the following fields:

`name::AbstractString`
:    The tenant's name

`id::Int64`
:    The tenant's ID

`body::XMLElement`
:    An XML object representing the app's XML definition

`parentID::Int64`
:    The ID of the parent folder that this tenant is in

`parentType::AbstractString`
:    The type of parent object (typically `tenantFolder`)

`path::AbstractString`
:    The folder path that this tenant is in

`description::AbstractString`
:    The description of this app entered into mPulse

`created::DateTime`
:    The timestamp when this object was created

`lastModified::DateTime`
:    The timestamp when this object was created

`attributes::Dict`
:    A `Dict` of attributes for this app, including its `App ID`

`dswbUrls::Array{AbstractString}`
:    An array of DSWB URLs that are valid auth redirect targets for this tenant


#### Throws
`ArgumentError`
:    if token is empty or tenantID and name are both empty

`mPulseAPIException`
:    if API access failed for some reason


---

## Namespaced Functions
 
!!! note
    The following methods are not exported by default. You may use them by explicitly
    importing them or by prefixing them with the `mPulseAPI.` namespace.


[RepositoryAPI.jl#445-480](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/RepositoryAPI.jl#L445-L480){: .source-link style="float:right;font-size:0.8em;"}
### function `getCustomMetricMap`

Gets a mapping of custom metric names to RedShift field names from domain XML.  This list also includes valid dates.

#### Arguments
`body::{AbstractString|XMLElement|Dict}`
:    This is an object containing the domain XML returned by `mPulseAPI.getRepositoryDomain`.  It may be:

     * An `AbstractString` containing the domain XML.  This will be parsed.
     * A `LightXML.XMLElement` pointing to the root node of the domain XML.
     * A `Dict` with a `body` element. This is the domain object returned by `mPulseAPI.getRepositoryDomain`.


#### Returns
`{Dict}` of Custom Metric names mapped to RedShift fieldnames with the following structure:

     Dict(
         <metric name> => Dict(
             "index"        => <index>,                          # Numeric index
             "fieldname"    => "custom_metrics_<index>",     # Field name in dswb tables
             "lastModified" => <lastModifiedDate>,
             "description"  => "<description>",
             "dataType"     => Dict(
                 "decimalPlaces"  => "2",
                 "type"           => "<metric type>",
                 "currencySymbol" => "<symbol if this is a currency type>"
             ),
             "colors"       => [<array of color HEX codes>]
         ),
         ...
     )

#### Throws
`ArgumentError`
:    if the data type of `body` is unknown.

`LightXML.XMLParseError`
:    if `body` is an `AbstractString` but contains invalid XML

---

[RepositoryAPI.jl#497-533](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/RepositoryAPI.jl#L497-L533){: .source-link style="float:right;font-size:0.8em;"}
### function `getCustomTimerMap`

Gets a mapping of custom timer names to RedShift field names from domain XML.  This list also includes valid dates.

#### Arguments
`body::{AbstractString|XMLElement|Dict}`
:    This is an object containing the domain XML returned by `mPulseAPI.getRepositoryDomain`.  It may be:

     * An `AbstractString` containing the domain XML.  This will be parsed.
     * A `LightXML.XMLElement` pointing to the root node of the domain XML.
     * A `Dict` with a `body` element. This is the domain object returned by `mPulseAPI.getRepositoryDomain`.


#### Returns
`{Dict}` of Custom Timer names mapped to RedShift fieldnames with the following structure:

     Dict(
         <timer name> => Dict(
             "index"         => <index>,                      # Numeric index
             "fieldname"     => "timers_custom<index>",       # Field name in dswb tables
             "mpulseapiname" => "CustomTimer<index>",
             "lastModified"  => <lastModifiedDate>,
             "description"   => "<description>",
             "colors"        => Array(
                 Dict(
                     "timingType"  => "<seconds | milliseconds>",
                     "timingStart" => "<start timer value for this colour range>",
                     "timingEnd"   => "<end timer value for this colour range>",
                     "colorStart"  => "<start of this color range>",
                     "endStart"    => "<end of this color range>"
                 ),
                 ...
             )
         ),
         ...
     )

#### Throws
`ArgumentError`
:    if the data type of `body` is unknown.

`LightXML.XMLParseError`
:    if `body` is an `AbstractString` but contains invalid XML

---

[RepositoryAPI.jl#557-581](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/RepositoryAPI.jl#L557-L581){: .source-link style="float:right;font-size:0.8em;"}
### function `getNodeContent`

Gets the content of a node

#### Arguments
`body::{AbstractString|XMLElement|Dict}`
:    This is an object containing the domain XML returned by `mPulseAPI.getRepositoryDomain`.  It may be:

     * An `AbstractString` containing the domain XML.  This will be parsed.
     * A `LightXML.XMLElement` pointing to the root node of the domain XML.
     * A `Dict` with a `body` element. This is the domain object returned by `mPulseAPI.getRepositoryDomain`.


`nodeName::AbstractString`
:    The node whose contents shoudl be returned

`default::Any`
:    A default value to return if the required node was not found


#### Returns
`{AbstractString|Number|Boolean}` The content of the requested node cast to the same type as `default` or the value of `default` if the node was not found

#### Throws
`ArgumentError`
:    if the data type of `body` is unknown.

`LightXML.XMLParseError`
:    if `body` is an `AbstractString` but contains invalid XML

---

