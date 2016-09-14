Communicate with the mPulse Query & Repository REST APIs to fetch information about tenants and apps.

## Quick and dirty usage
This snippet will get you up and running.  More explanation below

```julia
using mPulseAPI

# mPulse 57 uses apiToken for authentication
token = getRepositoryToken("<tenant name>", "<mPulse api token for tenant>")


# Get a domain by app name
domain = getRepositoryDomain(token, appName="<app name from mPulse>")

# Get a domain by App ID (formerly known as API key)
domain = getRepositoryDomain(token, appID="<App ID from mPulse>")

domain["attributes"]["appID"]                            # Gets the App ID (formerly known as API key)
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

