using Visualisations
using Documenter

DocMeta.setdocmeta!(Visualisations, :DocTestSetup, :(using Visualisations); recursive=true)

makedocs(;
    modules=[Visualisations],
    authors="Graham Stark",
    repo="https://github.com/grahamstark/Visualisations.jl/blob/{commit}{path}#{line}",
    sitename="Visualisations.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://grahamstark.github.io/Visualisations.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/grahamstark/Visualisations.jl",
)
