using Documenter, mPulseAPI

makedocs(
    sitename="mPulseAPI.jl Documentation",
    format=Documenter.HTML(
        prettyurls = false,
        edit_link="main",
        assets = [
            "favicon.ico"
        ]
    ),
    modules=[mPulseAPI],
    pages = ["index.md", "RepositoryAPI.md", "Alerts.md", "QueryAPI.md", "apiToken.md", "caching.md", "exceptions.md"],
)

deploydocs(
    repo = "github.com/akamai/mPulseAPI.jl.git",
    versions = nothing
)
