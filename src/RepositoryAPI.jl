###################################################
#
# Copyright Akamai, Inc.
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


"""
Internal convenience function.  Fetches an object from the repository and caches it for an hour in the appropriate cache object
- Returns a single object if `searchKey`s are passed in an `filterRequired` is set to `true` (default)
- Returns an array of objects if `searchKey`s are not passed in and `filterRequired` is set to `false`
- Throws an exception if `searchKey`s are not passed in and `filterRequired` is set to `true`
"""
function getRepositoryObject(token::AbstractString, objectType::AbstractString, searchKey::Dict{Symbol, Any}; filterRequired::Bool=true)
    global verbose

    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end

    isKeySet = false

    if filterRequired
        isKeySet = any(kv -> isa(kv[2], Number) ? kv[2] > 0 : !isempty(kv[2]), searchKey)

        if !isKeySet
            throw(ArgumentError("At least one of `$(join(collect(keys(searchKey)), "', `", "' or `"))' must be set"))
        end
    end

    object = getObjectFromCache(objectType, searchKey)

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



"""
Internal convenience function.  Updates an object from the repository.
"""
function postRepositoryObject(
    token::AbstractString,
    objectType::AbstractString,
    searchKey::Dict{Symbol, Any};
    attributes::Dict                                 = Dict(),
    objectFields::Dict                               = Dict(),
    body::Union{AbstractString, LightXML.XMLElement} = "",
    filterRequired::Bool                             = true
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

    isKeySet = false

    if filterRequired
        isKeySet = any(kv -> isa(kv[2], Number) ? kv[2] > 0 : !isempty(kv[2]), searchKey)

        if !isKeySet
            throw(ArgumentError("At least one of `$(join(collect(keys(searchKey)), "', `", "' or `"))' must be set"))
        end
    end

    url = ObjectEndpoint * "/" * objectType * "/$(objectID)"
    debugID = "(all)"

    if verbose
        println("POST $url")
        println("X-Auth-Token: $token")
        !isempty(attributes) && println(attributes)
        !isempty(objectFields) && println(objectFields)
    end

    json = buildPostJSON(objectType, objectID, objectFields, oldAttributes, attributes, body)

    handlePostResponse(url, objectType, objectID, json, token)

end



"""
Internal convenience function.  Deletes an object from the repository.
"""
function deleteRepositoryObject(token::AbstractString,
                              objectType::AbstractString,
                              searchKey::Dict{Symbol, Any}
)

    global verbose

    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end


    if !any(kv -> isa(kv[2], Number) ? kv[2] > 0 : !isempty(kv[2]), searchKey)
        throw(ArgumentError("At least one of `$(join(collect(keys(searchKey)), "', `", "' or `"))' must be set"))
    end

    objectID = get(searchKey, :id, 0)
    name = get(searchKey, :name, "")

    object = getObjectInfo(token, objectType, objectID, name)

    # If objectID was not supplied, it will now be available
    objectID = get(object, "id", 0)

    url = ObjectEndpoint * "/" * objectType * "/$(objectID)"
    debugID = "(all)"

    if verbose
        println("DELETE $url")
        println("X-Auth-Token: $token")
    end

    resp = HTTP.delete(url,
        Dict("X-Auth-Token" => token, "Content-type" => "application/json"),
        status_exception=false
    )

    if resp.status != 204
        error("Error deleting $(objectType), id = $(objectID).")
    end

    return resp

end




# Internal convenience function used to POST to repository
function postHttpRequest(url::AbstractString, objectType::AbstractString, objectID::Int64, json::Dict{AbstractString, Any}, token::AbstractString)
    # This may throw on network error, but we'll allow the caller to deal with that
    resp = HTTP.post(url,
                     Dict("X-Auth-Token" => token, "Content-type" => "application/json"),
                     JSON.json(json),
                     status_exception = false
           )


    # 400 - Bad request.  The URL or JSON is invalid
    # 404 - Not found.  The requested object does not exist
    if resp.status == 400 || resp.status == 404
        throw(mPulseAPIException("Error updating $(objectType) $(objectID)", resp))
    end

    return resp
end


# Internal convenience function for handling POST REST API Responses
function handlePostResponse(url::AbstractString, objectType::AbstractString, objectID::Int64, json::Dict{AbstractString, Any}, token::AbstractString)
    count = 0
    while count <= 5
        resp = postHttpRequest(url, objectType, objectID, json, token)

        if resp.status == 204 # Success
            return resp

        elseif resp.status == 401 # Unauthorized.  The security token is missing or invalid.
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
            # If body is a String, we'll check that it is well formed XML
            try
                xdoc = parse_string(body)
                xroot = root(xdoc)
            catch ex
                if objectType == "alert" || objectType == "statisticalmodel"
                    @error "errorXML is not formatted correctly" exception=ex
                else
                    @error "body keyword argument is not formatted correctly" exception=ex
                end
                rethrow()
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

    url = ObjectEndpoint * "/" * objectType
    query = Dict()
    debugID = "(all)"

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

    resp = HTTP.get(url, Dict("X-Auth-Token" => token), query=query, status_exception=false)

    respStatusCode = resp.status

    if respStatusCode == 401
        throw(mPulseAPIAuthException(resp))
    elseif respStatusCode == 500
        throw(mPulseAPIBugException(resp))
    elseif respStatusCode != 200
        throw(mPulseAPIException("Error fetching $(objectType) $(debugID)", resp))
    end

    json = String(resp.body)
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
