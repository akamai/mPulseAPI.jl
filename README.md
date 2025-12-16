Communicate with the mPulse Query & Repository REST APIs to fetch information about tenants and apps.

[![GH Build](https://github.com/akamai/mPulseAPI.jl/workflows/CI/badge.svg)](https://github.com/akamai/mPulseAPI.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage Status](https://coveralls.io/repos/github/akamai/mPulseAPI.jl/badge.svg?branch=main)](https://coveralls.io/github/akamai/mPulseAPI.jl?branch=main)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://akamai.github.io/mPulseAPI.jl/)

## Documentation

### This module:
* mPulseAPI.jl: [https://akamai.github.io/mPulseAPI.jl/](https://akamai.github.io/mPulseAPI.jl/)

### REST API that this module uses:
* mPulse API: [https://techdocs.akamai.com/mpulse/reference/api](https://techdocs.akamai.com/mpulse/reference/api)

## Quick and dirty usage
This snippet will get you up and running, see the full documentation for more details.

See [how to generate an API Token](/docs/src/apiToken.md) for details about the `apiToken`

```julia
using mPulseAPI

# mPulse uses apiToken for authentication
token = getRepositoryToken("<tenant name>", "<mPulse api token for tenant>")


# Get a domain by app name
domain = getRepositoryDomain(token, appName="<app name from mPulse>")

# Get a domain by App Key (formerly known as API key)
domain = getRepositoryDomain(token, appKey="<App Key from mPulse>")

domain["attributes"]["appKey"]                           # Gets the App Key (formerly known as API key)
                                                         # for this app
domain["custom_metrics"]                                 # Get a Dict of custom metrics
domain["custom_metrics"]["Conversion Rate"]              # Get mapping for Conversion Rate custom metric
domain["custom_metrics"]["Conversion Rate"]["fieldname"] # Get field name for Conversion Rate custom
                                                         # metric

# Get all domains in tenant
domains = getRepositoryDomain(token)


# Get a tenant
tenant = getRepositoryTenant(token, name="<tenant name from mPulse>")
```

## More examples

### Get the boomerang version used by an app
```julia
using mPulseAPI

# Authenticate, then get tenant and domain
token = getRepositoryToken("<tenant name from mPulse>", "<mPulse api token for tenant>")

tenant = getRepositoryTenant(token, name="<tenant name from mPulse>")
domain = getRepositoryDomain(token, appName="<app name from mPulse>")


# The boomerang version is stored in the references array
tenant_boomerang = filter(r -> r["type"] == "boomerang", tenant["references"])
domain_boomerang = filter(r -> r["type"] == "boomerang", domain["references"])

# The domain may use a flavor of the tenant boomerang, so pull that out of the attributes:
# Use an empty string if no flavor is specified because if a flavor was previously set and
# now removed, mPulse will set it to an empty string.
# The value is numeric otherwise.
boomerang_flavor = get(domain["attributes"], "flavorPatchVersion", "")

# We can also get the previous version of boomerang used. This is stored in the BODY element.
# The `getXMLNode` function will parse XML stored in a string or in the `body` element of the passed in object.
tenant_prev_boomerang = mPulseAPI.getXMLNode(tenant, "PreviousBoomerang")
if !isnothing(tenant_prev_boomerang)
    tenant_prev_boomerang = mPulseAPI.getNodeContent(tenant_prev_boomerang, "Version", nothing)
end

domain_prev_boomerang = mPulseAPI.getXMLNode(domain, "PreviousBoomerang")
if !isnothing(domain_prev_boomerang)
    domain_prev_boomerang = mPulseAPI.getNodeContent(domain_prev_boomerang, "Version", nothing)
end


# Boomerang stored in references has the `boomerang-` prefix, so remove that.
expected_boomerang = replace((isempty(domain_boomerang) ? tenant_boomerang : domain_boomerang)[1]["name"], "boomerang-" => "")
tenant_boomerang   = replace(tenant_boomerang[1]["name"], "boomerang-" => "")
previous_boomerang = something(domain_prev_boomerang, isempty(domain_boomerang) ? nothing : tenant_boomerang, tenant_prev_boomerang, "-1")

# If we have a flavor, update the inherited boomerang version to include it.
if boomerang_flavor != ""
    expected_boomerang = VersionNumber(expected_boomerang)
    expected_boomerang = VersionNumber(expected_boomerang.major, expected_boomerang.minor, boomerang_flavor)
    expected_boomerang = string(expected_boomerang)
end


# We now have `expected_boomerang`, `previous_boomerang` and `tenant_boomerang` as three separate variables

(expected_boomerang, previous_boomerang, tenant_boomerang)
```

### Get all apps that accept Bot Beacons
```julia
using mPulseAPI

# Authenticate, then get tenant and all domains
token = getRepositoryToken("<tenant name from mPulse>", "<mPulse api token for tenant>")
domains = getRepositoryDomain(token)

botty_domains = filter(d -> mPulseAPI.getNodeContent(d["body"], "KeepBots", false), domains)
```
