* `token::AbstractString`       The Repository authentication token fetched by calling `mPulseAPI.getRepositoryToken`
* `appID::AbstractString`       The App ID (formerly known as API key) for the app to query.  If you don't know the App ID, use `mPulseAPI.getRepositoryDomain`
                                to fetch a domain and then inspect `domain["attributes"]["appID"]`
