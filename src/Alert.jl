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
function getRepositoryAlert(token::AbstractString; alertID::Int64=0)

    alert = getRepositoryObject(
                token,
                "alert",
                Dict{Symbol, Any}(:id => alertID)
        )

    return alert

end




"""

TODO: documentation 

"""

function postRepositoryAlert(token::AbstractString;
                            alertID::Int64=0,
                            attributes::Dict=Dict(),
                            objectFields::Dict=Dict()
)

    postRepositoryObject(
        token,
        "alert",
        Dict{Symbol, Any}(:id => alertID),
        attributes = attributes,
        objectFields = objectFields
    )

    alert = getRepositoryAlert(token, alertID=alertID)

    return alert

end


