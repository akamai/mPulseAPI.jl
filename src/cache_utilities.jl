const caches = Dict{AbstractString, Dict}()

function writeObjectToCache(cacheType::AbstractString, searchKey::Dict{Symbol, Any}, object::Dict)
    if !haskey(caches, cacheType)
        caches[cacheType] = Dict()
    end

    # Store object in cache for 1 hour
    object["lastCached"] = now()

    for ky in keys(searchKey)
        k = string(ky)
        v = searchKey[ky]
        if v ∈ [0, ""]
            v = haskey(object, k) ? object[k] : haskey(object, "attributes") && haskey(object["attributes"], k) ? object["attributes"][k] : nothing
        end

        if v != nothing
            caches[cacheType]["$(k)_$(v)"] =  object
        end
    end
end

function getObjectFromCache(cacheType::AbstractString, searchKey::Dict{Symbol, Any}, fetchStale::Bool=false)
    if !haskey(caches, cacheType)
        return nothing
    end

    cache = caches[cacheType]

    for (k, v) in searchKey
        if isa(v, Number) ? v > 0 : v != ""
            if haskey(cache, "$(k)_$(v)") && (fetchStale || cache["$(k)_$(v)"]["lastCached"] > now() - Dates.Hour(1))
                return cache["$(k)_$(v)"]
            end
        end
    end

    return nothing
end


# Internal convenience method for clearing object cache
function clearObjectCache(cacheType::AbstractString, searchKey::Dict{Symbol, Any})
    local object = getObjectFromCache(cacheType, searchKey)

    if object == nothing
        return false
    end

    done = false
    if isa(object, Dict)
        for ky in keys(searchKey)
            k = string(ky)
            v = haskey(object, k) ? object[k] : haskey(object["attributes"], k) ? object["attributes"][k] : nothing

            if typeof(v) != Nothing
                delete!(caches[cacheType], "$(ky)_$(v)")
                done = true
            end
        end
    end

    return done
end


"""
Expire an entry from the domain cache.  Use this if the domain has changed.

### Keyword Arguments
`domainID::Int64`
:    The ID of the domain to expire.

`appKey::AbstractString`
:    The App Key (formerly known as API key) associated with the domain.  This is available from the mPulse domain configuration dialog.

`appName::AbstractString`
:    The App name in mPulse.  This can be got from the mPulse domain configuration dialog.


### Returns
`true`
:    on success

`false`
:    if the entry was not in cache

"""
clearDomainCache(;domainID::Int64=0, appKey::AbstractString="", appName::AbstractString="") = clearObjectCache("domain", Dict{Symbol, Any}(:id => domainID, :apiKey => appKey, :name => appName))

"""
Expire an entry from the tenant cache.  Use this if the tenant has changed.

### Keyword Arguments
`tenantID::Int64`
:    The ID of the tenant to expire.

`name::AbstractString`
:    The Tenant name in mPulse.  This is got from the mPulse domain configuration dialog.


### Returns
`true`
:    on success

`false`
:    if the entry was not in cache

"""
clearTenantCache(;tenantID::Int64=0, name::AbstractString="") = clearObjectCache("tenant", Dict{Symbol, Any}(:id => tenantID, :name => name))


"""
Expire an entry from the token cache.  Use this if the token associated with this tenant is no longer valid.

### Arguments
`tenant::AbstractString`
:    The tenant name whose token needs to be expired


### Returns
`true`
:    on success

`false`
:    if the entry was not in cache

"""
function clearTokenCache(tenant::AbstractString)
    # Unlike the other caches, this one only resets the timestamp
    # because we still want to cache credentials that were passed
    # in previously to make authentication easier
    tenant = "tenant_$tenant"
    if haskey(caches["token"], tenant)
        caches["token"][tenant]["lastCached"] = caches["token"][tenant]["tokenTimestamp"] = Date(0)
        return true
    end

    return false
end


"""
Expire an entry from the alert cache.  Use this if the alert has changed.

### Keyword Arguments
`alertID::Int64`
:    The ID of the alert to expire.

`alertName::AbstractString`
:    The Alert name in mPulse.  This can be found from the mPulse alert configuration dialog.

### Returns
`true`
:    on success

`false`
:    if the entry was not in cache

"""
clearAlertCache(;alertID::Int64=0, alertName::AbstractString="") = clearObjectCache("alert", Dict{Symbol, Any}(:id => alertID, :name => alertName))


"""
Expire an entry from the statistical model cache.  Use this if the model has changed.

### Keyword Arguments
`statModelID::Int64`
:    The ID of the statistical model to expire.

`statModelName::AbstractString`
:    The statistical model name in mPulse.  This can be found from the mPulse statistical model configuration dialog.

### Returns
`true`
:    on success

`false`
:    if the entry was not in cache

"""
clearStatModelCache(;statModelID::Int64=0, statModelName::AbstractString="") = clearObjectCache("statisticalmodel", Dict{Symbol, Any}(:id => statModelID, :name => statModelName))
