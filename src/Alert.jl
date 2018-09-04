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
    getRepositoryAlert,
    postRepositoryAlert

"""

TODO: documentation 

Fetches an Alert object from the mPulse repository

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

TODO: documentation 

"""

# postRepositoryWithChecks 
# pass in argument -> objectType

function postRepositoryAlert(token::AbstractString;
                            alertID::Int64=0,
                            alertName::AbstractString="",
                            attributes::Dict=Dict(),
                            objectFields::Dict=Dict()
)

    if token == ""
        throw(ArgumentError("`token' cannot be empty"))
    end

    # Make sure alertID exists and is accessible by user's token.
    if alertID > 0
        mPulseAPI.clearAlertCache(alertID = alertID)
        try
            preTestAlert = getRepositoryAlert(token, alertID = alertID)
        catch y 
            if isa(y, mPulseAPI.mPulseAPIException) && startswith(y.msg, "Error fetching alert id=")
                error("Error fetching alert id = $(alertID).  Please use a valid alertID.")
            end
        end
    end

    alert = postRepositoryObject(
                token,
                "alert", # pass in ObjectType instead
                Dict{Symbol, Any}(:id => alertID, :name => alertName),
                attributes = attributes,
                objectFields = objectFields
        )


    # Make sure correct alertID has been retrieved. 
    mPulseAPI.clearAlertCache(alertID = alertID)
    postTestAlert = getRepositoryAlert(token, alertID = alertID)
    if postTestAlert["id"] != alertID
        error("Failed to update correct alert object.")
    end

    return alert

end


