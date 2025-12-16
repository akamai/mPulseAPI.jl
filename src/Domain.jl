###################################################
#
# Copyright © Akamai Technologies. All rights reserved.
#
# File: Domain.jl
#
# Functions to communicate with the mPulse Repository REST API regarding Domain Objects.
# This file MUST be `include()`d from `mPulseAPI.jl`
#
###################################################

export
    getRepositoryDomain

"""
Fetches a Domain object from the mPulse repository

To fetch a single domain, at least one of `domainID`, `appKey` or `appName` must be passed in to identify the domain.
If none of these are passed in, then all domains that are readable by the specified `token` will be returned as an array.

The domain will be cached in memory for 1 hour, so subsequent calls using a matching `domainID`, `appKey` or `appName` return
quickly without calling out to the API.  This can be a problem if the domain changes in the repository.
You can clear the cache for this domain using [`mPulseAPI.clearDomainCache`](@ref) and passing in one of `domainID`, `appKey` or `appName`.

### Arguments
`token::AbstractString`
:    The Repository authentication token fetched by calling [`getRepositoryToken`](@ref)

### Keyword Arguments
`domainID::Int64`
:    The ID of the domain to fetch.  This is the fastest method, but it can be hard to figure out a domain's ID

`appKey::AbstractString`
:    The App Key (formerly known as API key) associated with the domain.  This is available from the mPulse domain configuration dialog.

`appName::AbstractString`
:    The App name in mPulse. This is available from the mPulse domain configuration dialog.

`filters::Dict{Symbol, Any}`
:    A `Dict` of additional filters to use if searching for multiple domains. See https://techdocs.akamai.com/mpulse/reference/get-objects-attribute for supported filters.

### Returns
`{Dict|Array{Dict}}` If one of `domainID`, `appKey` or `appName` are passed in, then a single `domain` object is returned as a `Dict`.

If none of these are passed in, then an array of all domains is returned, each is a `Dict`.

The `domain` `Dict` has the following fields:

`name`
:    The app's name

`id::Int64`
:    The app's ID

`body::LightXML.XMLElement`
:    An XML object representing the app's XML definition. You can use [`getXMLNode`](@ref) and [`getNodeContent`](@ref) from `mPulseAPI.xml_utilities`,
     or use [LightXML.jl](https://github.com/JuliaIO/LightXML.jl) directly to parse this object.  `LightXML` is available as `mPulseAPI.LightXML` when you call
     `using mPulseAPI`.

`tenantID::Int64`
:    The ID of the tenant that this app is in

`description::AbstractString`
:    The description of this app entered into mPulse

`created::DateTime`
:    The timestamp when this object was created

`lastModified::DateTime`
:    The timestamp when this object was created

`attributes::Dict`
:    A `Dict` of attributes for this app, including its `AppKey`

`custom_metrics::Dict`
:    A $(mPulseAPI.readdocs("CustomMetricMap-structure"))


`custom_timers::Dict`
:    A $(mPulseAPI.readdocs("CustomTimerMap-structure"))


`session_timeout::Int64`
:    The session timeout value in minutes

`resource_timing::Bool`
:    Flag indicating whether resource timing collection is enabled or not

`vertical_market::AbstractString`
:    The vertical market that this domain belongs to


### Throws
`ArgumentError`
:    if token is empty or domainID, appKey and appName are all empty

`mPulseAPIException`
:    if API access failed for some reason

`Exception`
:    if something unexpected happened while parsing the repository object

"""
function getRepositoryDomain(token::AbstractString; domainID::Int64=0, appKey::AbstractString="", appName::AbstractString="", appID::AbstractString="", filters::Dict{Symbol, Any}=Dict{Symbol, Any}())
    # Keep appID for backwards compatibility
    if isempty(appKey) && !isempty(appID)
        appKey = appID
    end

    domain_list = getRepositoryObject(
                token,
                "domain",
                Dict{Symbol, Any}(:id => domainID, :apiKey => appKey, :name => appName);
                filterRequired=false,
                filters
        )

    # Always convert to an array for easier processing
    if !isa(domain_list, AbstractArray)
        domain_list = Dict{AbstractString, Any}[domain_list]
    end

    for domain in domain_list
        # If the object came out of cache, then these fields have already been populated
        if !haskey(domain, "custom_metrics")
            try
                domain["custom_metrics"]  = getCustomMetricMap(domain)
                domain["custom_timers"]   = getCustomTimerMap(domain)
                domain["session_timeout"] = getNodeContent(domain, "SessionTimeout", 30)
                domain["resource_timing"] = getNodeContent(domain, "CollectResources", false)
                domain["vertical_market"] = getNodeContent(domain, "VerticalMarket", "")
            catch ex
                # If this is an Exception that we are not prepared to deal with
                if !isa(ex, LightXML.XMLParseError)
                    rethrow()
                end
            end
        end

        domain["custom_dimensions"] = "Custom Dimension map for a beacon is stored in the beacon and is more accurate and timely than the repository"

        domain["dswb_table_name"]   = "beacons_$(domain["id"])"

        if haskey(domain, "attributes") && haskey(domain["attributes"], "apiKey")
            domain["attributes"]["appID"] = domain["attributes"]["apiKey"]
            domain["attributes"]["appKey"] = domain["attributes"]["apiKey"]
        end

        delete!(domain, "readOnly")
    end

    # Return the first element only if the caller asked for a unique domain, else
    # return the list even if it only has one element in it
    if domainID != 0 || appKey != "" || appName != ""
        return domain_list[1]
    else
        return domain_list
    end
end



"""
Gets a mapping of custom metric names to database field names from domain XML.  This list also includes valid dates.

### Arguments
$(mPulseAPI.readdocs("NodeContent-body"))

### Returns
$(mPulseAPI.readdocs("CustomMetricMap-structure"))

### Throws
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
                "index" => parse(Int, attributes["index"], base=10),
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
Gets a mapping of custom timer names to database field names from domain XML.  This list also includes valid dates.

### Arguments
$(mPulseAPI.readdocs("NodeContent-body"))

### Returns
$(mPulseAPI.readdocs("CustomTimerMap-structure"))

### Throws
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
                "index" => parse(Int, attributes["index"], base=10),
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
