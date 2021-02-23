using Documenter, DynamicGrids, KernelAbstractions

makedocs(
    modules = [DynamicGrids],
    sitename = "DynamicGrids.jl",
    strict = true,
)

deploydocs(
    repo = "github.com/cesaraustralia/DynamicGrids.jl.git",
)
