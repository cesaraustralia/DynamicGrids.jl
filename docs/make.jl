using Documenter, DynamicGrids

makedocs(
    modules = [DynamicGrids],
    sitename = "DynamicGrids.jl",
)

deploydocs(
    repo = "github.com/rafaqz/DynamicGrids.jl.git",
)
