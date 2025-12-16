"""
Gets the content of a node

### Arguments
$(mPulseAPI.readdocs("NodeContent-body"))

`nodeName::AbstractString`
:    The node whose contents shoudl be returned

`default::Any`
:    A default value to return if the required node was not found


### Returns
`{AbstractString|Number|Boolean}` The content of the requested node cast to the same type as `default` or the value of `default` if the node was not found

### Throws
$(mPulseAPI.readdocs("NodeContent-throws"))
"""
function getNodeContent(body::Any, nodeName::AbstractString, default::Any)
    node = getXMLNode(body, nodeName)

    # If we have a valid node, get its textContent
    if isa(node, LightXML.XMLElement)
        value = content(node)

        # If the default value passed in was a Number, then we cast value to a Number
        if isa(default, AbstractFloat)
            value = parse(Float64, value)
        elseif isa(default, Int)
            value = parse(Int, value, base=10)
        elseif isa(default, Bool)
            if lowercase(value) == "true"
                value = true
            else
                value = false
            end
        end
    else
        value = default
    end

    return value
end




"""
Internal convenience function to get an XML node from a body
### Arguments
`body::Any`
:    The body to search. Can be an XML String, a LightXML.XMLElement or a Dict() with a `body` element.

`nodeName::AbstractString`
:    The node to find

### Returns
`{LightXML.XMLElement|Nothing}` The requested node or `nothing` if it was not found
"""
function getXMLNode(body::Any, nodeName::AbstractString)
    if isa(body, AbstractString)
        xdoc = parse_string(body)
        xroot = root(xdoc)
    elseif isa(body, LightXML.XMLElement)
        xroot = body
    elseif isa(body, Dict) && haskey(body, "body")
        xroot = body["body"]
    else
        throw(ArgumentError("bodyXML must either be an XML String, a LightXML.XMLElement or a Dict() with a `body` element. $(typeof(body)) is unknown."))
    end

    return find_element(xroot, nodeName)
end
