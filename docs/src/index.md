# mPulseAPI


[mPulseAPI.jl#16](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/mPulseAPI.jl#L16-L16){: .source-link style="float:right;font-size:0.8em;"}
## module `mPulseAPI`

Communicate with the mPulse [Query](http://docs.soasta.com/query-api/) & [Repository](http://docs.soasta.com/repository-api/) REST APIs to fetch information about tenants and apps.

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



---

## Table of Contents


* [Exceptions](exceptions.md)

    * [mPulseAPIException](exceptions.md#datatype-mpulseapiexception)
    * [mPulseAPIAuthException](exceptions.md#datatype-mpulseapiauthexception)
    * [mPulseAPIRequestException](exceptions.md#datatype-mpulseapirequestexception)
    * [mPulseAPIResultFormatException](exceptions.md#datatype-mpulseapiresultformatexception)

* [Repository API](RepositoryAPI.md)

    * [getRepositoryToken](RepositoryAPI.md#function-getrepositorytoken)
    * [getRepositoryDomain](RepositoryAPI.md#function-getrepositorydomain)
    * [getRepositoryTenant](RepositoryAPI.md#function-getrepositorytenant)

* [Query API](QueryAPI.md)

    * [getAPIResults](QueryAPI.md#function-getapiresults)
    * [getSummaryTimers](QueryAPI.md#function-getsummarytimers)
    * [getPageGroupTimers](QueryAPI.md#function-getpagegrouptimers)
    * [getBrowserTimers](QueryAPI.md#function-getbrowsertimers)
    * [getABTestTimers](QueryAPI.md#function-getabtesttimers)
    * [getMetricsByDimension](QueryAPI.md#function-getmetricsbydimension)
    * [getTimersMetrics](QueryAPI.md#function-gettimersmetrics)
    * [getGeoTimers](QueryAPI.md#function-getgeotimers)
    * [getHistogram](QueryAPI.md#function-gethistogram)
    * [getSessionsOverPageLoadTime](QueryAPI.md#function-getsessionsoverpageloadtime)
    * [getMetricOverPageLoadTime](QueryAPI.md#function-getmetricoverpageloadtime)
    * [getTimerByMinute](QueryAPI.md#function-gettimerbyminute)
    * [mergeMetrics](QueryAPI.md#function-mergemetrics)

* [Repository API](RepositoryAPI.md)

    * [getCustomMetricMap](RepositoryAPI.md#function-getcustommetricmap)
    * [getCustomTimerMap](RepositoryAPI.md#function-getcustomtimermap)
    * [getNodeContent](RepositoryAPI.md#function-getnodecontent)

* [Internal Cache Utilities](cache_utilities.md)

    * [clearDomainCache](cache_utilities.md#function-cleardomaincache)
    * [clearTenantCache](cache_utilities.md#function-cleartenantcache)
    * [clearTokenCache](cache_utilities.md#function-cleartokencache)
