###################################################
#
# Copyright 2016 SOASTA, Inc.
# Distributed under the terms of the MIT license
#
# File: RepositoryAPI.jl
#
# Functions to communicate with the mPulse Repository REST API
# This file MUST be `include()`d from `mPulseAPI.jl`
#
###################################################

export
    getRepositoryToken,
    getRepositoryTenant,
    getRepositoryDomain,
    postRepositoryObject

const TokenTimeoutHours = 5




"""
Logs in to the mPulse repository and fetches an Authorization token that can be used for other calls

The token will be cached in memory for 5 hours, so subsequent calls using the same tenant will return
quickly without calling out to the API.  This can be a problem if the account has signed in from a different
location or is logged out of mPulse.  You can clear the cache for this token using [`mPulseAPI.clearTokenCache`](@ref)

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
"""
function getRepositoryToken(tenant::AbstractString, apiToken::AbstractString)
    println("testing function - getRepositoryToken")
    global verbose

    if tenant == ""
        throw(ArgumentError("`tenant' cannot be empty"))
    end

    # Fetch object from cache again, but this time do not fetch stale objects
    object = getObjectFromCache("token", Dict{Symbol, Any}(:tenant => tenant))

    if object != nothing
        return object["token"]
    end


    # If no apiToken was passed in, check if we have it cached in an expired cache entry
    if apiToken == ""
        object = getObjectFromCache("token", Dict{Symbol, Any}(:tenant => tenant), true)

        if object == nothing || object["apiToken"] == ""
            throw(ArgumentError("`apiToken' cannot be empty"))
        else
            apiToken = object["apiToken"]
        end
    end

    if verbose
        println("PUT $TokenEndpoint")
        println("Content-Type: application/json")
        println(Dict("tenant" => tenant, "apiToken" => apiToken))
    end

    resp = Requests.put(TokenEndpoint,
        json = Dict("tenant" => tenant, "apiToken" => apiToken),
        headers = Dict("Content-type" => "application/json")
    )

    if statuscode(resp) != 200
        throw(mPulseAPIAuthException(resp))
    end

    resp = Requests.json(resp)

    object = Dict(
        "apiToken" => apiToken,
        "token" => resp["token"],
        "tokenTimestamp" => now()
    )

    writeObjectToCache("token", Dict{Symbol, Any}(:tenant => tenant), object)

    return object["token"]
end




"""
Fetches a Domain object from the mPulse repository

To fetch a single domain, at least one of `domainID`, `appKey` or `appName` must be passed in to identify the domain.
If none of these are passed in, then all domains that are readable by the specified `token` will be returned as an array.

The domain will be cached in memory for 1 hour, so subsequent calls using a matching `domainID`, `appKey` or `appName` return
quickly without calling out to the API.  This can be a problem if the domain changes in the repository.
You can clear the cache for this domain using [`mPulseAPI.clearDomainCache`](@ref) and passing in one of `domainID`, `appKey` or `appName`.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Optional Arguments
`domainID::Int64`
:    The ID of the domain to fetch.  This is the fastest method, but it can be hard to figure out a domain's ID

`appKey::AbstractString`
:    The App Key (formerly known as API key) associated with the domain.  This is available from the mPulse domain configuration dialog.

`appName::AbstractString`
:    The App name in mPulse. This is available from the mPulse domain configuration dialog.

#### Returns
`{Dict|Array{Dict}}` If one of `domainID`, `appKey` or `appName` are passed in, then a single `domain` object is returned as a `Dict`.

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
:    A `Dict` of attributes for this app, including its `AppKey`

`custom_metrics::Dict`
:    A $(mPulseAPI.readdocs("CustomMetricMap-structure", indent=5))


`custom_timers::Dict`
:    A $(mPulseAPI.readdocs("CustomTimerMap-structure", indent=5))


`session_timeout::Int64`
:    The session timeout value in minutes

`resource_timing::Bool`
:    Flag indicating whether resource timing collection is enabled or not

`vertical_market::AbstractString`
:    The vertical market that this domain belongs to


#### Throws
`ArgumentError`
:    if token is empty or domainID, appKey and appName are all empty

`mPulseAPIException`
:    if API access failed for some reason

`Exception`
:    if something unexpected happened while parsing the repository object

"""
function getRepositoryDomain(token::AbstractString; domainID::Int64=0, appKey::AbstractString="", appName::AbstractString="", appID::AbstractString="")
    # Keep appID for backwards compatibility
    if isempty(appKey) && !isempty(appID)
        appKey = appID
    end

    domain_list = getRepositoryObject(
                token,
                "domain",
                Dict{Symbol, Any}(:id => domainID, :apiKey => appKey, :name => appName),
                filterRequired=false
        )

    # Always convert to an array for easier processing
    if !isa(domain_list, Array)
        domain_list = [domain_list]
    end

    for domain in domain_list
        # If the object came out of cache, then these fields have already been populated
        if !haskey(domain, "custom_metrics")
            try
                domain["custom_metrics"]  = getCustomMetricMap(domain)
                domain["custom_timers"]   = getCustomTimerMap(domain)
                domain["session_timeout"] = getNodeContent(domain, "SessionTimeout", 30)
                domain["resource_timing"] = getNodeContent(domain, "CollectResources", false)
                domain["vertical_market"] = getNodeContent(domain, "VerticalMarket", "")
            catch ex
                # If this is an Exception that we are not prepared to deal with
                if !isa(ex, LightXML.XMLParseError)
                    rethrow()
                end
            end
        end

        domain["custom_dimensions"] = "Custom Dimension map for a beacon is stored in the beacon and is more accurate and timely than the repository"

        domain["dswb_table_name"]   = "beacons_$(domain["id"])"

        if haskey(domain, "attributes") && haskey(domain["attributes"], "apiKey")
            domain["attributes"]["appID"] = domain["attributes"]["apiKey"]
            domain["attributes"]["appKey"] = domain["attributes"]["apiKey"]
        end

        delete!(domain, "readOnly")
    end

    # Return the first element only if the caller asked for a unique domain, else
    # return the list even if it only has one element in it
    if domainID != 0 || appKey != "" || appName != ""
        return domain_list[1]
    else
        return domain_list
    end
end




"""
Fetches a Tenant object from the mPulse repository

At least one of `tenantID` or `name` must be passed in to identify the tenant.

The tenant will be cached in memory for 1 hour, so subsequent calls using a matching `tenantID`, or `name` return
quickly without calling out to the API.  This can be a problem if the tenant changes in the repository.
You can clear the cache for this tenant using [`mPulseAPI.clearTenantCache`](@ref) and passing in one of `tenantID` or `name`.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

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
:    An XML object representing the tenant's XML definition or an empty node if you do not have permission to see the full tenant

`parentID::Int64`
:    The ID of the parent folder that this tenant is in

`parentType::AbstractString`
:    The type of parent object (typically `tenantFolder`)

`path::AbstractString`
:    The folder path that this tenant is in

`description::AbstractString`
:    The description of this tenant entered into mPulse

`created::DateTime`
:    The timestamp when this object was created

`lastModified::DateTime`
:    The timestamp when this object was created

`attributes::Dict`
:    A `Dict` of attributes for this tenant

`dswbUrls::Array{AbstractString}`
:    An array of DSWB URLs that are valid auth redirect targets for this tenant


#### Throws
`ArgumentError`
:    if token is empty or tenantID and name are both empty

`mPulseAPIException`
:    if API access failed for some reason

"""
function getRepositoryTenant(token::AbstractString; tenantID::Int64=0, name::AbstractString="")
    tenant = getRepositoryObject(
                token,
                "tenant",
                Dict{Symbol, Any}(:id => tenantID, :name => name)
        )

    # If the object came out of cache, then it already contains these fields
    if !haskey(tenant, "dswbUrls")
        try
            tenant["dswbUrls"] = filter(u -> u != "", split(getNodeContent(tenant, "DSWBURLs", ""), ','))
        catch ex
            # If this is an Exception that we are not prepared to deal with
            if !isa(ex, LightXML.XMLParseError)
                rethrow()
            end
        end
    end

    tenant["dswb_dsn_name"] = "tenant_$(tenant["id"])"

    return tenant
end



  # tenant = getRepositoryObject(
  #               token,
  #               "tenant",
  #               Dict{Symbol, Any}(:id => tenantID, :name => name)
  #       )

# Internal convenience function.  Fetches an object from the repository and caches it for an hour in the appropriate cache object
# - Returns a single object if filter keys are passed in an filterRequired is set to true (default)
# - Returns an array of objects if filter keys are not passed in and filterRequired is set to false
# - Throws an exception if filter keys are not passed in and filterRequired is set to true
function getRepositoryObject(token::AbstractString, objectType::AbstractString, searchKey::Dict{Symbol, Any}; filterRequired::Bool=true)
    global verbose

    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end

    local isKeySet = false

    if filterRequired
        isKeySet = any(kv -> isa(kv[2], Number) ? kv[2] > 0 : !isempty(kv[2]), searchKey)

        if !isKeySet
            throw(ArgumentError("At least one of `$(join(collect(keys(searchKey)), "', `", "' or `"))' must be set"))
        end
    end

    local object = getObjectFromCache(objectType, searchKey)

    if object != nothing
        println("getObjectFromCache")
        return object
    end

    local url = ObjectEndpoint * "/" * objectType
    local query = Dict()
    local debugID = "(all)"

    # Adjust query URL to use ID or search attribute depending on which is passed in
    for (k, v) in searchKey
        if isa(v, Number) ? v > 0 : v != ""
            if k == :id
                url *= "/$(v)"
            else
                query[k] = v
            end
            debugID = "$(k)=$(v)"
            break
        end
    end


    if verbose
        println("GET $url")
        println("X-Auth-Token: $token")
        println(query)
    end

################################################################
# from getRepositoryToken
    # resp = Requests.put(TokenEndpoint,
    #     json = Dict("tenant" => tenant, "apiToken" => apiToken),
    #     headers = Dict("Content-type" => "application/json")
    # )
################################################################


    # Attempt to fetch object from repository using auth token
    resp = Requests.get(url, headers=Dict("X-Auth-Token" => token), query=query)

    if statuscode(resp) == 401
        throw(mPulseAPIAuthException(resp))
    elseif statuscode(resp) == 500
        throw(mPulseAPIBugException(resp))
    elseif statuscode(resp) != 200
        throw(mPulseAPIException("Error fetching $(objectType) $(debugID)", resp))
    end

    # Do not use Requests.json as that expects UTF-8 data, and mPulse API's response is ISO-8859-1
    json = join(map(Char, resp.data))
    object = JSON.parse(json)

    # If calling by a searchKey other than ID, the return value will be a Dict with a single key="objects"
    # and value set to an array of domain objects.
    # If searching by ID, then the object is returned, so turn it into an array
    if haskey(object, "objects") && isa(object["objects"], Array)
        object_list = object["objects"]
    else
        object_list = [object]
    end

    if length(object_list) == 0
        throw(mPulseAPIException("An object matching $debugID was not returned", resp))
    # If caller has passed in a filter key, then we should only get a single object
    elseif isKeySet && length(object_list) > 1
        throw(mPulseAPIException("Found too many matching objects with IDs=($(map(d->d["id"], object_list)))", resp))
    end


    for object in object_list
        if !isempty(object["body"])
            # Convert body string to an actual XML root object
            xdoc = parse_string(object["body"])
            xroot = root(xdoc)
        else
            # LightXML cannot handle empty strings, so just fake it
            xdoc = XMLDocument()
            xroot = create_root(xdoc, "")
        end

        object["body"] = xroot
        object["created"] = iso8601ToDateTime(object["created"])
        object["lastModified"] = iso8601ToDateTime(object["lastModified"])

        object["attributes"] = Dict(
            map(attr -> attr["name"] => fixJSONDataType(attr["value"]), object["attributes"])
        )

        delete!(object, "schemaVersion")
        delete!(object, "type")
        delete!(object, "effectivePermissions")

        writeObjectToCache(objectType, searchKey, object)
    end

    if isKeySet
        return object_list[1]
    else
        return object_list
    end
end





"""

TODO: documentation 

"""

function postRepositoryObject(token::AbstractString,
                              objectType::AbstractString,
                              searchKey::Dict{Symbol, Any},
                              name::AbstractString="",
                              tenantID::Int64=0;
                              attributes=Dict{AbstractString, Any},
                              filterRequired::Bool=true
)

    global verbose

    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end

    # If tenantID is not supplied, retrieve from getRepositoryTenant
    if tenantID == 0 
        tenant = getRepositoryTenant(token, name = name)
        tenantID = get(tenant, "id", 0)
    end

    local isKeySet = false

    if filterRequired
        isKeySet = any(kv -> isa(kv[2], Number) ? kv[2] > 0 : !isempty(kv[2]), searchKey)

        if !isKeySet
            throw(ArgumentError("At least one of `$(join(collect(keys(searchKey)), "', `", "' or `"))' must be set"))
        end
    end

    # local object = getObjectFromCache(objectType, searchKey)

    # if object != nothing
    #     println("getObjectFromCache")
    #     return object
    # end

    local url = ObjectEndpoint * "/" * objectType * "/$(tenantID)"
    local query = Dict()
    local debugID = "(all)"


    # Adjust query URL to use ID or search attribute depending on which is passed in
    for (k, v) in searchKey
        if isa(v, Number) ? v > 0 : v != ""
            if k == :id
                url *= "/$(v)"
            else
                query[k] = v
            end
            debugID = "$(k)=$(v)"
            break
        end
    end


    if verbose
        println("POST $url")
        println("X-Auth-Token: $token")
        # println(query)
    end


    json = Dict{AbstractString, Any}()
    json["type"] = objectType

    if haskey(query, "name")
        json["name"] = query["name"]
    end

    attributesDict = []
    for (key, val) in attributes
        push!(attributesDict, Dict("name" => key, "value"=> val))
    end

    if !isempty(attributesDict)
        json["attributes"] = attributesDict
    end

    resp = Requests.post(url,
        json = json,
        headers = Dict("X-Auth-Token" => token, "Content-type" => "application/json")
    )


end



"""
Gets a mapping of custom metric names to RedShift field names from domain XML.  This list also includes valid dates.

#### Arguments
$(mPulseAPI.readdocs("NodeContent-body"))

#### Returns
$(mPulseAPI.readdocs("CustomMetricMap-structure"))

#### Throws
$(mPulseAPI.readdocs("NodeContent-throws"))
"""
function getCustomMetricMap(body::Any)
    custom_metrics = Dict()

    cmets = getXMLNode(body, "CustomMetrics")

    if !isa(cmets, XMLElement)
        return custom_metrics
    end

    for node in child_elements(cmets)
        attributes = attributes_dict(node)
        if attributes["inactive"] == "false"
            custom_metric = Dict(
                "index" => parse(Int, attributes["index"], 10),
                "fieldname" => "custom_metrics_" * attributes["index"],
                "lastModified" => iso8601ToDateTime(attributes["lastModified"]),
                "description" => attributes["description"]
            )

            datatypeNode = getXMLNode(node, "DataType")
            if isa(datatypeNode, XMLElement)
                custom_metric["dataType"] = attributes_dict(datatypeNode)
            end

            colorNode = getXMLNode(node, "MetricColors")
            if isa(colorNode, XMLElement)
                colors = attributes_dict(colorNode)
                custom_metric["colors"] = map(k->colors[k], sort(collect(keys(colors))))
            end

            custom_metrics[attributes["name"]] = custom_metric
        end
    end

    return custom_metrics
end




"""
Gets a mapping of custom timer names to RedShift field names from domain XML.  This list also includes valid dates.

#### Arguments
$(mPulseAPI.readdocs("NodeContent-body"))

#### Returns
$(mPulseAPI.readdocs("CustomTimerMap-structure"))

#### Throws
$(mPulseAPI.readdocs("NodeContent-throws"))
"""
function getCustomTimerMap(body::Any)
    custom_timers = Dict()

    ctims = getXMLNode(body, "CustomTimers")

    if !isa(ctims, XMLElement)
        return custom_timers
    end

    for node in child_elements(ctims)
        attributes = attributes_dict(node)
        if attributes["inactive"] == "false"
            custom_timer = Dict(
                "index" => parse(Int, attributes["index"], 10),
                "fieldname" => "timers_custom" * attributes["index"],
                "mpulseapiname" => "CustomTimer" * attributes["index"],
                "lastModified" => iso8601ToDateTime(attributes["lastModified"]),
                "description" => attributes["description"]
            )

            colorNodes = getXMLNode(node, "TimingColors")
            if isa(colorNodes, XMLElement)
                colors = Dict[]
                for colorNode in child_elements(colorNodes)
                    color = attributes_dict(colorNode)
                    push!(colors, color)
                end
                custom_timer["colors"] = colors
            end


            custom_timers[attributes["name"]] = custom_timer
        end
    end

    return custom_timers
end




"""
Gets the content of a node

#### Arguments
$(mPulseAPI.readdocs("NodeContent-body"))

`nodeName::AbstractString`
:    The node whose contents shoudl be returned

`default::Any`
:    A default value to return if the required node was not found


#### Returns
`{AbstractString|Number|Boolean}` The content of the requested node cast to the same type as `default` or the value of `default` if the node was not found

#### Throws
$(mPulseAPI.readdocs("NodeContent-throws"))
"""
function getNodeContent(body::Any, nodeName::AbstractString, default::Any)
    node = getXMLNode(body, nodeName)

    # If we have a valid node, get its textContent
    if isa(node, LightXML.XMLElement)
        value = content(node)

        # If the default value passed in was a Number, then we cast value to a Number
        if isa(default, AbstractFloat)
            value = parse(Float64, value, 10)
        elseif isa(default, Int)
            value = parse(Int, value, 10)
        elseif isa(default, Bool)
            if lowercase(value) == "true"
                value = true
            else
                value = false
            end
        end
    else
        value = default
    end

    return value
end




# Internal convenience function
function getXMLNode(body::Any, nodeName::AbstractString)
    if isa(body, AbstractString)
        xdoc = parse_string(body)
        xroot = root(xdoc)
    elseif isa(body, LightXML.XMLElement)
        xroot = body
    elseif isa(body, Dict) && haskey(body, "body")
        xroot = body["body"]
    else
        throw(ArgumentError("bodyXML must either be an XML String, a LightXML.XMLElement or a Dict() with a `body` element. $(typeof(body)) is unknown."))
    end

    return find_element(xroot, nodeName)
end
