using Documenter, DynamicGrids, CUDAKernels

makedocs(
    modules = [DynamicGrids],
    sitename = "DynamicGrids.jl",
    checkdocs = :all,
    strict = true,
)

deploydocs(
    repo = "github.com/cesaraustralia/DynamicGrids.jl.git",
)
