@test mPulseAPI.default_SOASTAEndpoint == "https://mpulse.soasta.com/concerto"

@test isconst(mPulseAPI, :default_SOASTAEndpoint)

if !isempty(endpoint)
    @test mPulseAPI.ObjectEndpoint == "$(endpoint)/services/rest/RepositoryService/v1/Objects"
    @test mPulseAPI.mPulseEndpoint == "$(endpoint)/mpulse/api/v2/"
else
    @test mPulseAPI.ObjectEndpoint == "$(mPulseAPI.default_SOASTAEndpoint)/services/rest/RepositoryService/v1/Objects"
    @test mPulseAPI.mPulseEndpoint == "$(mPulseAPI.default_SOASTAEndpoint)/mpulse/api/v2/"
end


new_endpoint = "https://foo.bar.com"

@test mPulseAPI.setEndpoints(new_endpoint) == ("$new_endpoint/mpulse/api/v2/", "$new_endpoint/services/rest/RepositoryService/v1")

@test mPulseAPI.ObjectEndpoint == "$(new_endpoint)/services/rest/RepositoryService/v1/Objects"
@test mPulseAPI.mPulseEndpoint == "$(new_endpoint)/mpulse/api/v2/"

@test mPulseAPI.setEndpoints() == ("$(mPulseAPI.default_SOASTAEndpoint)/mpulse/api/v2/", "$(mPulseAPI.default_SOASTAEndpoint)/services/rest/RepositoryService/v1")

@test mPulseAPI.ObjectEndpoint == "$(mPulseAPI.default_SOASTAEndpoint)/services/rest/RepositoryService/v1/Objects"
@test mPulseAPI.mPulseEndpoint == "$(mPulseAPI.default_SOASTAEndpoint)/mpulse/api/v2/"
