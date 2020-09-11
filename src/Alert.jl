###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
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

At least one of `alertID` or `alertName` must be passed in to identify the alert.

The alert will be cached in memory for 1 hour, so subsequent calls using a matching `alertID` return
quickly without calling out to the API.  This can be a problem if the alert changes in the repository.
You can clear the cache for this tenant using [`mPulseAPI.clearAlertCache`](@ref) and passing in `alertID`.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Keyword Arguments
`alertID::Int64`
:    The ID of the alert to fetch.

`alertName::AbstractString`
:    The Alert name in mPulse. This is available from the mPulse domain configuration dialog.

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
:    The ID of the tenant that the alert is in

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
:    An array of `Dict`s with reference information such as `name`, `id`, `type`, and `path`.

`uid::AbstractString`
:    The encrypted uid associated with the alert

`deleted::Bool`
:    Flag indicating whether the alert has been deleted

`ownerID::Int64`
:    The ID of the alert's owner

`attributes::Dict`
:    A `Dict` containing whether the alert is active, version number, and the time(s) that the alert was last cleared, triggered, and updated.

`lastModified::DateTime`
:    The timestamp when this object was created

#### Throws
`ArgumentError`
:    if token is empty or alertID is empty

`mPulseAPIException`
:    if API access failed for some reason
"""
function getRepositoryAlert(token::AbstractString; alertID::Int64=0, alertName::AbstractString="")

    alert_list = getRepositoryObject(
                token,
                "alert",
                Dict{Symbol, Any}(:id => alertID, :name => alertName),
                filterRequired=false
        )

    # Always convert to an array for easier processing
    if !isa(alert_list, AbstractArray)
        alert_list = Dict{AbstractString, Any}[alert_list]
    end

    # Convert alert attribute dates to ZonedDateTime
    dateFormat = "y-m-dTH:M:S.s+z"
    for alert in alert_list
        alertAttributes = alert["attributes"]
        for lastTimestamp in ["lastCleared", "lastTriggered", "lastUpdated"]
            alertAttributes[lastTimestamp] = isa(alertAttributes[lastTimestamp], AbstractString) ? ZonedDateTime(alertAttributes[lastTimestamp], dateFormat) : alertAttributes[lastTimestamp]
        end
    end

    # Return the first element only if the caller asked for a unique alert, else
    # return the list even if it only has one element in it
    if alertID != 0 || alertName != ""
        return alert_list[1]
    else
        return alert_list
    end
end



"""
Updates an Alert object from the mPulse repository

At least one of `alertID` or `alertName` must be passed in to update the alert object.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Keyword Arguments
`alertID::Int64`
:    The ID of the alert to update.

`alertName::AbstractString`
:    The Alert name in mPulse. This is available from the mPulse domain configuration dialog.

`attributes::Dict`
:    A `Dict` of alert attributes to update

`objectFields::Dict`
:    A `Dict` of alert object fields to update

`body::AbstractString|LightXML.XMLElement=""`
:    An XMLElement (if not empty) containing the body of the alert, containing pertinent information surrounding errors.

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

`errorXML::Union{AbstractString, LightXML.XMLElement}`
:    An XML object representing the alert's XML error definition to be updated by the repository.

`references::Dict`
:    An array of `Dict`s with reference information such as `name`, `id`, `type`, and `path`.

`uid::AbstractString`
:    The encrypted uid associated with the alert

`deleted::Bool`
:    Flag indicating whether the alert has been deleted

`ownerID::Int64`
:    The ID of the alert's owner

`attributes::Dict`
:    A `Dict` containing whether the alert is active, version number, and the time(s) that the alert was last cleared, triggered, and updated.

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
                            objectFields::Dict=Dict(),
                            alertBody::Union{AbstractString, LightXML.XMLElement}="",
                            errorXML::Union{AbstractString, LightXML.XMLElement}="" # deprecated, remains here for backwards compatibility
)
    # Renaming errorXML argument to alertBody; safeguard until all code is updated
    if isempty(alertBody) && errorXML != ""
        alertBody = errorXML
    end

    postRepositoryObject(
        token,
        "alert",
        Dict{Symbol, Any}(:id => alertID, :name => alertName),
        attributes = attributes,
        objectFields = objectFields,
        body = alertBody
    )

    return nothing
end


"""
Deletes an Alert object from the mPulse repository

At least one of `alertID` or `alertName` must be passed in to delete the alert object.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Keyword Arguments
`alertID::Int64`
:    The ID of the alert to update.

`alertName::AbstractString`
:    The Alert name in mPulse. This is available from the mPulse domain configuration dialog.

#### Returns
Returns true if the delete is successful, else false.

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

    return statuscode(resp) == 204
end
