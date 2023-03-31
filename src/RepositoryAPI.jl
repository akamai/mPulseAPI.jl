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
        return object
    else
        object_list = getHttpRequest(token, objectType, searchKey, isKeySet)
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
                              filterRequired::Bool=true
)

    global verbose

    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end

    objectID = get(searchKey, :id, 0)
    name = get(searchKey, :name, "")

    object = getObjectInfo(token, objectType, objectID, name)

    # If objectID was not supplied, it will now be available
    objectID = get(object, "id", 0)

    # Retrieve existing (old) attributes
    oldAttributes = Dict{AbstractString, Any}(get(object, "attributes", Dict()))

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
    end

    json = buildPostJSON(objectType, objectID, objectFields, oldAttributes, attributes, body)

    handlePostResponse(url, objectType, objectID, json, token)

end



# Internal convenience function.  Deletes an object from the repository.
function deleteRepositoryObject(token::AbstractString,
                              objectType::AbstractString,
                              searchKey::Dict{Symbol, Any}
)

    global verbose

    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end

    objectID = get(searchKey, :id, 0)
    name = get(searchKey, :name, "")

    object = getObjectInfo(token, objectType, objectID, name)

    # If objectID was not supplied, it will now be available
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


# Internal convenience function used to POST to repository
function postHttpRequest(url::AbstractString, objectType::AbstractString, objectID::Int64, json::Dict{AbstractString, Any}, token::AbstractString)
    resp = nothing

    try
        resp = Requests.post(url,
                             json = json,
                             headers = Dict("X-Auth-Token" => token, "Content-type" => "application/json")
                        )
    catch er
        if isa(er, Base.UVError)
            error("TCP timeout")
        else
            error("We have not encountered this error before.  Please report this. Timestamp: $(round(Int, datetime2unix(now())))")
        end
    end

    # 400 - Bad request.  The URL or JSON is invalid
    # 404 - Not found.  The requested object does not exist
    if statuscode(resp) == 400 || statuscode(resp) == 404
        throw(mPulseAPIException("Error updating $(objectType) $(objectID)", resp))
    end

    return resp
end


# Internal convenience function for handling POST REST API Responses
function handlePostResponse(url::AbstractString, objectType::AbstractString, objectID::Int64, json::Dict{AbstractString, Any}, token::AbstractString)
    count = 0
    while count <= 5
        resp = postHttpRequest(url, objectType, objectID, json, token)

        if statuscode(resp) == 204 # Success
            return resp
        elseif statuscode(resp) == 401 # Unauthorized.  The security token is missing or invalid.
            # Retry once
            if count > 1
                throw(mPulseAPIAuthException(resp))
            end

            count += 1
        else # Internal server error.  Try again later. Expecting 500 < resp < 509
            # Retry up to 5 times
            if count <= 5
                count += 1
            else
                throw(mPulseAPIBugException(resp))
            end
        end
    end
end

# Internal convenience function for building object JSON entry used in POST
function buildPostJSON(
    objectType::AbstractString,
    objectID::Int64,
    objectFields::Dict=Dict(),
    oldAttributes::Dict=Dict(),
    attributes::Dict=Dict(),
    body::Union{AbstractString, LightXML.XMLElement}=""
)
    # Initialize JSON Dict
    json = Dict{AbstractString, Any}()
    json["type"] = objectType
    json["id"] = objectID

    # If attributes is supplied, update the object’s attributes field
    if !isempty(attributes)
        attributes = convert(Dict{AbstractString, Any}, attributes)

        if objectType == "statisticalmodel"
        # Merge existing and new attributes needed for statisticalmodel
            for key in keys(oldAttributes)
                if !haskey(attributes, key)
                    attributes[key] = oldAttributes[key]
                end
            end
        end

        attributesDict = []

        for (key, val) in attributes
            push!(attributesDict, Dict("name" => key, "value"=> val))
        end

        json["attributes"] = attributesDict

    end

    # If any objectFields are supplied by the user, update these in the object (if it exists)
    if !isempty(objectFields)
        for (key, val) in objectFields
            json[key] = val
        end
    end

    # If the bodyError argument is supplied, update this in the object
    if body != ""
        if isa(body, AbstractString)
            try
                xdoc = parse_string(body)
                xroot = root(xdoc)
            catch
                if objectType == "alert" || objectType == "statisticalmodel"
                    error("errorXML is not formatted correctly")
                else
                    error("body keyword argument is not formatted correctly")
                end
            end
        else
            body = string(body)
        end
        json["body"] = body
    end

    return json
end

# Internal convenience function used to GET from repository
function getHttpRequest(token::AbstractString, objectType::AbstractString, searchKey::Dict{Symbol, Any}, isKeySet::Bool)

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

    resp = Requests.get(url, headers=Dict("X-Auth-Token" => token), query=query)

    respStatusCode = statuscode(resp)

    if respStatusCode == 401
        throw(mPulseAPIAuthException(resp))
    elseif respStatusCode == 500
        throw(mPulseAPIBugException(resp))
    elseif respStatusCode != 200
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
        # Either no objects are defined in the repository, or the specific object was not found
        if debugID == "(all)"
            throw(mPulseAPIException("There are no objects defined in the $objectType repository.", resp))
        else
            throw(mPulseAPIException("An object matching $debugID was not returned", resp))
        end
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

    return object_list

end
