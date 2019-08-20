###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
#
# File: StatisticalModel.jl
#
# Functions to communicate with the mPulse Repository REST API regarding Statistical Model Objects.
# This file MUST be `include()`d from `mPulseAPI.jl`
#
###################################################

export
    deleteRepositoryStatModel,
    getRepositoryStatModel,
    postRepositoryStatModel

"""
Fetches an StatisticalModel object from the mPulse repository

At least one of `statModelID` or `statModelName` must be passed in to identify the statistical model.

The statistical model will be cached in memory for 1 hour, so subsequent calls using a matching `statModelID` return
quickly without calling out to the API.  This can be a problem if the statistical model changes in the repository.
You can clear the cache for this tenant using [`mPulseAPI.clearStatModelCache`](@ref) and passing in `statModelID`.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Keyword Arguments
`statModelID::Int64`
:    The ID of the statistical model to update.

`statModelName::AbstractString`
:    The statistical model name in mPulse. This is available from the mPulse domain configuration dialog.

#### Returns
`{Dict}` The `statisticalmodel` object with the following fields:

`hidden::Bool`
:    Flag indicating whether the statistical model is visible to the user

`parentID::Int64`
:    The ID of the parent folder that this statistical model is in

`path::AbstractString`
:    The folder path that this statistical model is in

`readOnly::Bool`
:    Flag indicating whether the statistical model is able to be edited

`name::AbstractString`
:    The statistical model's name

`tenantID::Int64`
:    The ID of the tenant that the statistical model is in

`created::DateTime`
:    The timestamp when this object was created

`id::Int64`
:    The ID of the statistical model.

`description::AbstractString`
:    The description of this statistical model entered into mPulse

`lastCached::DateTime`
:    The timestamp when this object was last cached

`body::XMLElement`
:    An XML object representing the statistical model's XML definition or an empty node if you do not have permission to see the full statistical model

`references::Dict`
:    An array of `Dict`s with reference information such as `name`, `id`, `type`, and `path`.

`uid::AbstractString`
:    The encrypted uid associated with the statistical model

`deleted::Bool`
:    Flag indicating whether the statistical model has been deleted

`ownerID::Int64`
:    The ID of the statistical model's owner

`attributes::Dict`
:    A `Dict` containing whether the statistical model is active, version number, and the time(s) that the statistical model was last cleared, triggered, and updated.

`lastModified::DateTime`
:    The timestamp when this object was created

#### Throws
`ArgumentError`
:    if token is empty or statModelID is empty

`mPulseAPIException`
:    if API access failed for some reason
"""
function getRepositoryStatModel(token::AbstractString; statModelID::Int64=0, statModelName::AbstractString="")

    statModel = getRepositoryObject(
                token,
                "statisticalmodel",
                Dict{Symbol, Any}(:id => statModelID, :name => statModelName)
        )

    return statModel
end



"""
Updates an StatisticalModel object from the mPulse repository

At least one of `statModelID` or `statModelName` must be passed in to update the statistical model object.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Keyword Arguments
`statModelID::Int64`
:    The ID of the statistical model to update.

`statModelName::AbstractString`
:    The statistical model name in mPulse. This is available from the mPulse domain configuration dialog.

`attributes::Dict`
:    A `Dict` of statistical model attributes to update

`objectFields::Dict`
:    A `Dict` of statistical model object fields to update

`body::AbstractString|LightXML.XMLElement=""`
:    An XMLElement (if not empty) containing the body of the statistical model, containing pertinent information surrounding errors.

#### Returns
`{Dict}` The updated `statistical model` object with the following fields:

`hidden::Bool`
:    Flag indicating whether the statistical model is visible to the user

`parentID::Int64`
:    The ID of the parent folder that this statistical model is in

`path::AbstractString`
:    The folder path that this statistical model is in

`readOnly::Bool`
:    Flag indicating whether the statistical model is able to be edited

`name::AbstractString`
:    The statistical model's name

`tenantID::Int64`
:    The ID of the tenant in which the statistical model is in

`created::DateTime`
:    The timestamp when this object was created

`id::Int64`
:    The ID of the statistical model.

`description::AbstractString`
:    The description of this statistical model entered into mPulse

`lastCached::DateTime`
:    The timestamp when this object was last cached

`errorXML::Union{AbstractString, LightXML.XMLElement}`
:    An XML object representing the alert's XML error definition to be updated by the repository.

`references::Dict`
:    An array of `Dict`s with reference information such as `name`, `id`, `type`, and `path`.

`uid::AbstractString`
:    The encrypted uid associated with the statistical model

`deleted::Bool`
:    Flag indicating whether the statistical model has been deleted

`ownerID::Int64`
:    The ID of the statistical model's owner

`attributes::Dict`
:    A `Dict` containing whether the statistical model is active, version number, and the time(s) that the statistical model was last cleared, triggered, and updated.

`lastModified::DateTime`
:    The timestamp when this object was created

#### Throws
`ArgumentError`
:    if token is empty or statModelID is empty

`mPulseAPIException`
:    if API access failed for some reason


"""

function postRepositoryStatModel(token::AbstractString;
                            statModelID::Int64=0,
                            statModelName::AbstractString="",
                            attributes::Dict=Dict(),
                            objectFields::Dict=Dict(),
                            errorXML::Union{AbstractString, LightXML.XMLElement}=""
)

    postRepositoryObject(
        token,
        "statisticalmodel",
        Dict{Symbol, Any}(:id => statModelID, :name => statModelName),
        attributes = attributes,
        objectFields = objectFields,
        body = errorXML
    )
    
    return nothing

end


"""
Deletes an StatisticalModel object from the mPulse repository

At least one of `statModelID` or `statModelName` must be passed in to delete the Statistical Model object.

#### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

#### Keyword Arguments
`statModelID::Int64`
:    The ID of the statistical model to update.

`statModelName::AbstractString`
:    The statistical model name in mPulse. This is available from the mPulse domain configuration dialog.

#### Returns
Returns true if the delete is successful, else false.

#### Throws
`ArgumentError`
:    if token is empty or statModelID is empty

`mPulseAPIException`
:    if API access failed for some reason


"""

function deleteRepositoryStatModel(token::AbstractString;
                            statModelID::Int64=0,
                            statModelName::AbstractString=""
)

    resp = deleteRepositoryObject(
        token,
        "statisticalmodel",
        Dict{Symbol, Any}(:id => statModelID, :name => statModelName)
    )
    
    if statuscode(resp) == 204
        return true
    else
        return false
    end

end
