# RepositoryAPI

The RepositoryAPI performs all communication with the mPulse Repository. You use it first to authenticate, and
then to create, modify, query, and delete objects from the mPulse Repository.

## Connecting to the Repository

If using an alternate mPulse endpoint (for example, your dev system), you will first need to tell this module about
your endpoint:

```@docs
mPulseAPI.setEndpoints
```

## Authenticate with the Repository

To authenticate with the Repository, you will first need an [API Token](apiToken.md) from mPulse. Once you have the API
Token, you will call out to `getRepositoryToken` to authenticate and get a session token. This session token will be used
for all subsequent calls to the Repository and Query APIs. The session token is valid until you sign out of mPulse.

```@docs
mPulseAPI.getRepositoryToken
```

## Communicating with the Repository
This module provides wrappers for the `tenant`, `domain`, `alert` and `statisticalmodel` object types. While you can only fetch Tenant & Domain (aka Application) details using this API, you can do more with Alerts.

## Tenants, Domains & Applications

```@autodocs
Modules = [mPulseAPI]
Pages = ["Tenant.jl", "Domain.jl", "xml_utilities.jl"]
```

```@docs
mPulseAPI.clearTenantCache
mPulseAPI.clearDomainCache
```

## Alerts & Anomaly Detection

See the page on [Alerts & Anomaly Detection Models](@ref) for more details.

## Other Object Types

To interact with other object types, you will need to use the following sparsely documented internal methods:

```@autodocs
Modules = [mPulseAPI]
Order = [:function]
Private = false
Pages = ["RepositoryAPI.jl"]
```
