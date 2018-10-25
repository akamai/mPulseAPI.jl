###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
#
# File: Tenant.jl
#
# Functions to communicate with the mPulse Repository REST API regarding Tenant Objects.
# This file MUST be `include()`d from `mPulseAPI.jl`
#
###################################################


export
    getRepositoryTenant

"""
Fetches a Tenant object from the mPulse repository

At least one of `tenantID` or `name` must be passed in to identify the tenant.

The tenant will be cached in memory for 1 hour, so subsequent calls using a matching `tenantID`, or `name` return
quickly without calling out to the API.  This can be a problem if the tenant changes in the repository.
You can clear the cache for this tenant using [`mPulseAPI.clearTenantCache`](@ref) and passing in one of `tenantID` or `name`.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Keyword Arguments
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
function getRepositoryTenant(token::AbstractString; tenantID::Int64=0, name::AbstractString="", ObjectEndpoint::AbstractString="$ObjectEndpoint")
    tenant = getRepositoryObject(
                token,
                "tenant",
                Dict{Symbol, Any}(:id => tenantID, :name => name),
                ObjectEndpoint = ObjectEndpoint
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
