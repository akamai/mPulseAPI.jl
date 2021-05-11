# mPulseAPI


## module `mPulseAPI`
[mPulseAPI.jl#14](https://github.com/akamai/mPulseAPI.jl/tree/master/src/mPulseAPI.jl#L14-L14){: .source-link}

Communicate with the mPulse Query & Repository REST APIs to fetch information about tenants and apps.

## Documentation

### This module:
* mPulseAPI.jl: [https://akamai.github.io/mPulseAPI.jl/](https://akamai.github.io/mPulseAPI.jl/)

### REST APIs that this module uses:
* mPulse Query API: [https://developer.akamai.com/api/web_performance/mpulse_query/v2.html](https://developer.akamai.com/api/web_performance/mpulse_query/v2.html)
* mPulse Repository API: [https://developer.akamai.com/api/web_performance/mpulse_cloudtest_repository/v1.html](https://developer.akamai.com/api/web_performance/mpulse_cloudtest_repository/v1.html)

## Quick and dirty usage
This snippet will get you up and running, see the full documentation for more details.

See [how to generate an API Token](apiToken.md) for details about the `apiToken`

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



---

## Namespaced Functions
!!! note
    The following methods are not exported by default. You may use them by explicitly
    importing them or by prefixing them with the `mPulseAPI.` namespace.


### function `setEndpoints`
[mPulseAPI.jl#59-67](https://github.com/akamai/mPulseAPI.jl/tree/master/src/mPulseAPI.jl#L59-L67){: .source-link}

Change the mPulse API endpoint that we connect to.  The default is `https://mpulse.soasta.com/concerto`

#### Example

```julia
mPulseAPI.setEndpoints("https://mpulse-alt.soasta.com/concerto")
```

---

### function `setVerbose`
[mPulseAPI.jl#75-77](https://github.com/akamai/mPulseAPI.jl/tree/master/src/mPulseAPI.jl#L75-L77){: .source-link}

Set verbosity of API calls.

If set to true, all URLs, headers and POST data will be printed to the console before making an API call.

---

## API Reference


* [Exceptions](exceptions.md)

    * [mPulseAPIException](exceptions.md#datatype-mpulseapiexception)
    * [mPulseAPIAuthException](exceptions.md#datatype-mpulseapiauthexception)
    * [mPulseAPIRequestException](exceptions.md#datatype-mpulseapirequestexception)
    * [mPulseAPIResultFormatException](exceptions.md#datatype-mpulseapiresultformatexception)
    * [mPulseAPIBugException](exceptions.md#datatype-mpulseapibugexception)

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
    * [getGeoTimers](QueryAPI.md#function-getgeotimers)
    * [getMetricsByDimension](QueryAPI.md#function-getmetricsbydimension)
    * [getTimersMetrics](QueryAPI.md#function-gettimersmetrics)
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
