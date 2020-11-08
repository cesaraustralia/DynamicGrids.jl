using Documenter, DynamicGrids, Disributions
using DynamicGrids: AbstractSimData, SimData, GridData, ReadableGridData, WritableGridData,
      applyrule, applyrule!, inbounds

makedocs(
    modules = [DynamicGrids],
    sitename = "DynamicGrids.jl",
)

deploydocs(
    repo = "github.com/cesaraustralia/DynamicGrids.jl.git",
)
