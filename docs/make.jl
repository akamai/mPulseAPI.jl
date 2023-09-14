using Documenter, mPulseAPI

makedocs(
    sitename="mPulseAPI Documentation",
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
