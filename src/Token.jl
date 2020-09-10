###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
#
# File: Token.jl
#
# Functions to communicate with the mPulse Repository REST API regarding Token Objects.
# This file MUST be `include()`d from `mPulseAPI.jl`
#
###################################################

export
    getRepositoryToken

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

    resp = HTTP.put(TokenEndpoint,
        Dict("Content-type" => "application/json"),
        JSON.json(Dict("tenant" => tenant, "apiToken" => apiToken)),
        status_exception=false
    )

    if resp.status != 200
        throw(mPulseAPIAuthException(resp))
    end

    resp = JSON.parse(String(resp.body))

    object = Dict(
        "apiToken" => apiToken,
        "token" => resp["token"],
        "tokenTimestamp" => now()
    )

    writeObjectToCache("token", Dict{Symbol, Any}(:tenant => tenant), object)

    return object["token"]
end


