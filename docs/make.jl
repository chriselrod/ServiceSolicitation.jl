using ServiceSolicitation
using Documenter

makedocs(;
    modules=[ServiceSolicitation],
    authors="Chris Elrod <elrodc@gmail.com> and contributors",
    repo="https://github.com/"chriselrod"/ServiceSolicitation.jl/blob/{commit}{path}#L{line}",
    sitename="ServiceSolicitation.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://"chriselrod".github.io/ServiceSolicitation.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/"chriselrod"/ServiceSolicitation.jl",
)
