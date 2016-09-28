# Internal Cache Utilities


* [clearDomainCache](cache_utilities.md#function-cleardomaincache)
* [clearTenantCache](cache_utilities.md#function-cleartenantcache)
* [clearTokenCache](cache_utilities.md#function-cleartokencache)
## Namespaced Functions
 
!!! note
    The following methods are not exported by default. You may use them by explicitly
    importing them or by prefixing them with the `mPulseAPI.` namespace.


### function `clearDomainCache`
[cache_utilities.jl#87-137](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/cache_utilities.jl#L87-L137){: .source-link}

Expire an entry from the domain cache.  Use this if the domain has changed.

#### Optional Arguments
`domainID::Int64`
:    The ID of the domain to expire.

`appID::AbstractString`
:    The App ID (formerly known as API key) associated with the domain.  This is available from the mPulse domain configuration dialog.

`appName::AbstractString`
:    The App name in mPulse.  This can be got from the mPulse domain configuration dialog.


#### Returns
`true`
:    on success

`false`
:    if the entry was not in cache


---

### function `clearTenantCache`
[cache_utilities.jl#108-137](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/cache_utilities.jl#L108-L137){: .source-link}

Expire an entry from the tenant cache.  Use this if the tenant has changed.

#### Optional Arguments
`tenantID::Int64`
:    The ID of the tenant to expire.

`name::AbstractString`
:    The Tenant name in mPulse.  This is got from the mPulse domain configuration dialog.


#### Returns
`true`
:    on success

`false`
:    if the entry was not in cache


---

### function `clearTokenCache`
[cache_utilities.jl#127-137](https://github.com/SOASTA/mPulseAPI.jl/tree/master/src/cache_utilities.jl#L127-L137){: .source-link}

Expire an entry from the token cache.  Use this if the token associated with this tenant is no longer valid.

#### Arguments
`tenant::AbstractString`
:    The tenant name whose token needs to be expired


#### Returns
`true`
:    on success

`false`
:    if the entry was not in cache


---

