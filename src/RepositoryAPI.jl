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
    deleteRepositoryObject,
    getRepositoryObject,
    postRepositoryObject

const TokenTimeoutHours = 5


# Internal convenience function.  Fetches an object from the repository and caches it for an hour in the appropriate cache object
# - Returns a single object if filter keys are passed in an filterRequired is set to true (default)
# - Returns an array of objects if filter keys are not passed in and filterRequired is set to false
# - Throws an exception if filter keys are not passed in and filterRequired is set to true
function getRepositoryObject(token::AbstractString, objectType::AbstractString, searchKey::Dict{Symbol, Any}; filterRequired::Bool=true, ObjectEndpoint::AbstractString=mPulseAPI.ObjectEndpoint)
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



# Internal convenience function.  Updates an object from the repository.
function postRepositoryObject(token::AbstractString,
                              objectType::AbstractString,
                              searchKey::Dict{Symbol, Any};
                              attributes::Dict=Dict(),
                              objectFields::Dict=Dict(),
                              body::Union{AbstractString, LightXML.XMLElement}="",
                              ObjectEndpoint::AbstractString=mPulseAPI.ObjectEndpoint,
                              filterRequired::Bool=true
)

    global verbose

    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end

    objectID = get(searchKey, :id, 0)
    name = get(searchKey, :name, "")

    # If objectID is not supplied, retrieve from get function
    if objectID == 0
        if objectType == "alert"
            object = getRepositoryAlert(token, alertName = name, ObjectEndpoint=ObjectEndpoint)
        elseif objectType == "domain"
            object = getRepositoryDomain(token, appName = name, ObjectEndpoint=ObjectEndpoint)
        elseif objectType == "tenant"
            object = getRepositoryTenant(token, name = name, ObjectEndpoint=ObjectEndpoint)
        elseif objectType == "statisticalmodel"
            object = getRepositoryStatModel(token, statModelName = name, ObjectEndpoint=ObjectEndpoint)
        end
        objectID = get(object, "id", 0)
    end

    local isKeySet = false

    if filterRequired
        isKeySet = any(kv -> isa(kv[2], Number) ? kv[2] > 0 : !isempty(kv[2]), searchKey)

        if !isKeySet
            throw(ArgumentError("At least one of `$(join(collect(keys(searchKey)), "', `", "' or `"))' must be set"))
        end
    end

    local url = ObjectEndpoint * "/" * objectType * "/$(objectID)"
    local debugID = "(all)"

    if verbose
        println("POST $url")
        println("X-Auth-Token: $token")
        !isempty(attributes) && println(attributes)
        !isempty(objectFields) && println(objectFields)
        !isempty(body) && println(body)
    end


    json = Dict{AbstractString, Any}()
    json["type"] = objectType

    # If any objectFields are supplied by the user, update these in the object (if it exists)
    if !isempty(objectFields)
        for (key, val) in objectFields
            json[key] = val
        end
    end

    # If attributes is supplied, update the object’s attributes field
    if !isempty(attributes)
        attributesDict = []

        for (key, val) in attributes
            push!(attributesDict, Dict("name" => key, "value"=> val))
        end
        
        json["attributes"] = attributesDict
    end

    # If the body argument is supplied, update this in the object 
    if body != ""
        if isa(body, AbstractString)
            try
                xdoc = parse_string(body)
                xroot = root(xdoc)
            catch
                error("body string is not formatted correctly")
            end
        else
            body = string(body)
        end
        json["body"] = body
    end

    resp = Requests.post(url,
        json = json,
        headers = Dict("X-Auth-Token" => token, "Content-type" => "application/json")
    )

    if statuscode(resp) != 204
        throw(mPulseAPIException("Error updating $(objectType) $(objectID)", resp))
    end

    return resp

end



# Internal convenience function.  Deletes an object from the repository.
function deleteRepositoryObject(token::AbstractString,
                              objectType::AbstractString,
                              searchKey::Dict{Symbol, Any},
                              ObjectEndpoint::AbstractString=mPulseAPI.ObjectEndpoint
)

    global verbose

    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end

    objectID = get(searchKey, :id, 0)
    name = get(searchKey, :name, "")

    # If objectID is not supplied, retrieve from get function
    if objectID == 0 
        if objectType == "alert"
            object = getRepositoryAlert(token, alertName = name)
        elseif objectType == "domain"
            object = getRepositoryDomain(token, appName = name)
        elseif objectType == "tenant"
            object = getRepositoryTenant(token, name = name)
        end
    end

    objectID = get(object, "id", 0)

    local url = ObjectEndpoint * "/" * objectType * "/$(objectID)"
    local debugID = "(all)"

    if verbose
        println("DELETE $url")
        println("X-Auth-Token: $token")
    end

    resp = Requests.delete(url,
        headers = Dict("X-Auth-Token" => token, "Content-type" => "application/json")
    )

    if statuscode(resp) != 204
        error("Error deleting $(objectType), id = $(objectID).")
    end

    return resp

end






"""
Gets a mapping of custom metric names to Snowflake field names from domain XML.  This list also includes valid dates.

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
                "fieldname" => "custommetric" * attributes["index"],
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
Gets a mapping of custom timer names to Snowflake field names from domain XML.  This list also includes valid dates.

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
                "fieldname" => "customtimer" * attributes["index"],
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
