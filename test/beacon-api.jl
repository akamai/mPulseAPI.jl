config = mPulseAPI.getBeaconConfig(beaconKey, "mPulseAPIDemo.net")

@test config isa Dict
@test haskey(config, "site_domain")
@test config["site_domain"] == "mPulseAPIDemo.net"

if !haskey(config, "rate_limited")
    @test haskey(config, "h.cr")
    @test haskey(config, "h.d")
    @test haskey(config, "h.key")
    @test haskey(config, "h.t")

    t_end = Int(datetime2unix(now())*1000)
    @test mPulseAPI.sendBeacon(config, Dict("PageGroup" => "mPulseAPI Test", "tDone" => t_end - t_start, "Conversion" => 1, "ResourceTimer" => 500, "Url" => "https://github.com/akamai/mPulseAPI.jl/"))
end

config2 = mPulseAPI.getBeaconConfig(beaconKey, "mPulseAPIDemo.net")

@test config == config2
