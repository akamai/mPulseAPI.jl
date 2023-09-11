Communicate with the mPulse Query & Repository REST APIs to fetch information about tenants and apps.

[![Build Status](https://travis-ci.org/akamai/mPulseAPI.jl.svg?branch=master)](https://travis-ci.org/akamai/mPulseAPI.jl)

## Documentation

### This module:
* mPulseAPI.jl: [https://akamai.github.io/mPulseAPI.jl/](https://akamai.github.io/mPulseAPI.jl/)

### REST APIs that this module uses:
* mPulse Query API: [https://developer.akamai.com/api/web_performance/mpulse_query/v2.html](https://developer.akamai.com/api/web_performance/mpulse_query/v2.html)
* mPulse Repository API: [https://developer.akamai.com/api/web_performance/mpulse_cloudtest_repository/v1.html](https://developer.akamai.com/api/web_performance/mpulse_cloudtest_repository/v1.html)

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

