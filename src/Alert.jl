###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
# Proprietary and confidential.
#
# File: Alert.jl
#
# Functions to communicate with the mPulse Repository REST API regarding Alert Objects.
# This file MUST be `include()`d from `mPulseAPI.jl`
#
###################################################



export
    deleteRepositoryAlert,
    getRepositoryAlert,
    postRepositoryAlert

"""

Fetches an Alert object from the mPulse repository

The alert will be cached in memory for 1 hour, so subsequent calls using a matching `alertID` return
quickly without calling out to the API.  This can be a problem if the alert changes in the repository.
You can clear the cache for this tenant using [`mPulseAPI.clearAlertCache`](@ref) and passing in `alertID`.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Optional Arguments
`alertID::Int64`
:    The ID of the alert to fetch.

#### Returns
`{Dict}` The `alert` object with the following fields:

`hidden::Bool`
:    Flag indicating whether the alert is visible to the user

`parentID::Int64`
:    The ID of the parent folder that this alert is in

`path::AbstractString`
:    The folder path that this alert is in

`readOnly::Bool`
:    Flag indicating whether the alert is able to be edited

`name::AbstractString`
:    The alert's name

`tenantID::Int64`
:    The ID of the tenant in which the alert is in

`created::DateTime`
:    The timestamp when this object was created

`id::Int64`
:    The ID of the alert.

`description::AbstractString`
:    The description of this alert entered into mPulse

`lastCached::DateTime`
:    The timestamp when this object was last cached

`body::XMLElement`
:    An XML object representing the alert's XML definition or an empty node if you do not have permission to see the full alert

`references::Dict`
:    A `Dict` of locations in which this alert is referenced 

`uid::AbstractString`
:    The encrypted uid associated with the alert

`deleted::Bool`
:    Flag indicating whether the alert has been deleted

`ownerID::Int64`
:    The ID of the alert's owner

`attributes::Dict`
:    A `Dict` of attributes for this alert

`lastModified::DateTime`
:    The timestamp when this object was created

#### Throws
`ArgumentError`
:    if token is empty or alertID is empty

`mPulseAPIException`
:    if API access failed for some reason

"""
function getRepositoryAlert(token::AbstractString; alertID::Int64=0, alertName::AbstractString="")

    alert = getRepositoryObject(
                token,
                "alert",
                Dict{Symbol, Any}(:id => alertID, :name => alertName)
        )

    return alert

end



"""
Updates an Alert object from the mPulse repository

The alert will be cached in memory for 1 hour, so subsequent calls using a matching `alertID` return
quickly without calling out to the API.  This can be a problem if the alert changes in the repository.
You can clear the cache for this tenant using [`mPulseAPI.clearAlertCache`](@ref) and passing in `alertID`.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Optional Arguments
`alertID::Int64`
:    The ID of the alert to update.

`attributes::Dict`
:    A `Dict` of alert attributes to update

`objectFields::Dict`
:    A `Dict` of alert object fields to update

#### Returns
`{Dict}` The updated `alert` object with the following fields:

`hidden::Bool`
:    Flag indicating whether the alert is visible to the user

`parentID::Int64`
:    The ID of the parent folder that this alert is in

`path::AbstractString`
:    The folder path that this alert is in

`readOnly::Bool`
:    Flag indicating whether the alert is able to be edited

`name::AbstractString`
:    The alert's name

`tenantID::Int64`
:    The ID of the tenant in which the alert is in

`created::DateTime`
:    The timestamp when this object was created

`id::Int64`
:    The ID of the alert.

`description::AbstractString`
:    The description of this alert entered into mPulse

`lastCached::DateTime`
:    The timestamp when this object was last cached

`body::XMLElement`
:    An XML object representing the alert's XML definition or an empty node if you do not have permission to see the full alert

`references::Dict`
:    A `Dict` of locations in which this alert is referenced 

`uid::AbstractString`
:    The encrypted uid associated with the alert

`deleted::Bool`
:    Flag indicating whether the alert has been deleted

`ownerID::Int64`
:    The ID of the alert's owner

`attributes::Dict`
:    A `Dict` of attributes for this alert

`lastModified::DateTime`
:    The timestamp when this object was created

#### Throws
`ArgumentError`
:    if token is empty or alertID is empty

`mPulseAPIException`
:    if API access failed for some reason


"""

function postRepositoryAlert(token::AbstractString;
                            alertID::Int64=0,
                            alertName::AbstractString="",
                            attributes::Dict=Dict(),
                            objectFields::Dict=Dict()
)

    postRepositoryObject(
        token,
        "alert",
        Dict{Symbol, Any}(:id => alertID, :name => alertName),
        attributes = attributes,
        objectFields = objectFields
    )
    
    if alertID > 0 
        clearAlertCache(alertID = alertID )    
        alert = getRepositoryAlert(token, alertID=alertID)
    else
        clearAlertCache(alertName = alertName)
        alert = getRepositoryAlert(token, alertName=alertName)
    end

    return alert

end


"""
Deletes an Alert object from the mPulse repository

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Optional Arguments
`alertID::Int64`
:    The ID of the alert to update.

`alertName::AbstractString`
:    The Alert name in mPulse. This is available from the mPulse domain configuration dialog.

#### Returns
If the delete is successful, the response will be `204 No Content`.

#### Throws
`ArgumentError`
:    if token is empty or alertID is empty

`mPulseAPIException`
:    if API access failed for some reason


"""

function deleteRepositoryAlert(token::AbstractString;
                            alertID::Int64=0,
                            alertName::AbstractString=""
)

    resp = deleteRepositoryObject(
        token,
        "alert",
        Dict{Symbol, Any}(:id => alertID, :name => alertName)
    )
    
    return resp

end



