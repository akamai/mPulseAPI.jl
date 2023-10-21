"""
Base URL for config.json requests
"""
const CONFIG_URL = "https://c.go-mpulse.net/api/config.json"

"""
Fetch beacon configuration for an mPulse APP using the [Beacon API](https://techdocs.akamai.com/mpulse/reference/beacons#rest-api)
Caches the result for whatever is specified in `Cache-control: max-age`
"""
function getBeaconConfig(appKey::AbstractString, appDomain::AbstractString)
    config_obj = getObjectFromCache("beacon-config", Dict(:appKey => appKey))

    if !isnothing(config_obj)
        return config_obj
    end

    config = HTTP.get(CONFIG_URL, query = Dict("key" => appKey, "d" => appDomain))

    cache_headers = filter(h -> lowercase(h[1]) == "cache-control", config.headers)
    if isempty(cache_headers)
        cache_headers = Dict{AbstractString, AbstractString}()
    else
        cache_headers = Dict{AbstractString, AbstractString}(
            map(
                x -> Pair([split(x, "="); ""][1:2]...),
                split(
                    mapreduce(
                        h -> h[2],
                        (l, r) -> string(l, ", ", r),
                        cache_headers
                    ),
                    r", *"
                )
            )
        )
    end

    expiry = Dates.Second(parse(Int, get(cache_headers, "max-age", "300"); base=10))

    config_obj = JSON.parse(IOBuffer(config.body))

    writeObjectToCache("beacon-config", Dict(:appKey => appKey), config_obj; expiry)
    
    return config_obj
end

const mPulseSessions = Dict{String, Dict}()

"""
Send a beacon to mPulse
"""
function sendBeacon(config::Dict, params::Dict)
    beacon_url = "https:" * config["beacon_url"]

    now_ms = Int(datetime2unix(now())*1000)
    session_id = get(params, "SessionID", config["session_id"])

    session = get(mPulseSessions, session_id, Dict())
    session_ln = get(session, "sl", 0) + 1


    beacon_params = Dict{String, Any}(
        "api"      => 1,
        "api.v"    => 1,
        "h.cr"     => config["h.cr"],
        "h.d"      => config["h.d"],
        "h.key"    => config["h.key"],
        "h.t"      => config["h.t"],
        "rt.end"   => now_ms,
        "rt.si"    => session_id,
        "rt.sl"    => get(params, "SessionLength", session_ln),
        "rt.ss"    => get(session, "ss", get(params, "SessionStart", now_ms)),
        "rt.start" => "manual",
        "rt.obo"   => 0,
    )

    if haskey(params, "PageGroup")
        beacon_params["h.pg"] = params["PageGroup"]
    end
    if haskey(params, "Url")
        beacon_params["u"] = params["Url"]
    end
    if haskey(params, "tDone")
        beacon_params["t_done"] = params["tDone"]
        beacon_params["rt.tt"]  = get!(session, "tt", 0) + params["tDone"]
    end
    if haskey(params, "tStart")
        beacon_params["rt.tstart"] = params["tStart"]
    elseif haskey(params, "tDone")
        beacon_params["rt.tstart"] = now_ms - params["tDone"]
    end

    session[session_id] = Dict("sl" => beacon_params["rt.sl"], "ss" => beacon_params["rt.ss"], "tt" => beacon_params["rt.tt"])

    vars = ["customMetrics", "customDimensions", "customTimers"]
    t_other = []
    for v in vars
        for p in config["PageParams"][v]
            for k in ["label", "name"]
                if haskey(params, p[k])
                    if v == "customTimers"
                        push!(t_other, string(p["label"], "|", params[p[k]]))
                    else
                        beacon_params[p["label"]] = params[p[k]]
                    end
                    break
                end
            end
        end
    end

    if !isempty(t_other)
        beacon_params["t_other"] = join(t_other, ",")
    end


    params = merge(params, beacon_params)

    res = HTTP.get(beacon_url, query = params)

    return res.status == 204
end
