using Documenter, DynamicGrids, CUDAKernels

CI = get(ENV, "CI", nothing) == "true" || get(ENV, "GITHUB_TOKEN", nothing) !== nothing

makedocs(
    modules = [DynamicGrids],
    sitename = "DynamicGrids.jl",
    checkdocs = :all,
    strict = true,
    format = Documenter.HTML(
        prettyurls = CI,
    ),
    pages = [
        "DynamicGrids" => "index.md",
        # "Examples" => "examples.md",
    ],
)

deploydocs(
    repo = "github.com/cesaraustralia/DynamicGrids.jl.git",
)
