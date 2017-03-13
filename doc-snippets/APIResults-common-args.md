`token::AbstractString`
:    The Repository authentication token fetched by calling [`mPulseAPI.getRepositoryToken`](@ref)

`appKey::AbstractString`
:    The App Key (formerly known as API key) for the app to query.  If you don't know the App Key, use
     [`mPulseAPI.getRepositoryDomain`](@ref) to fetch a domain and then inspect `domain["attributes"]["appKey"]`
