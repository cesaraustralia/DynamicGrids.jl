using Documenter, DynamicGrids
using DynamicGrids: @Output, @Graphic, @Image, applyrule, applyrule!,
      setneighbor!, mapsetneighbor!, neighbors, sumneighbors,
      AbstractSimData, SimData, GridData, ReadableGridData, WritableGridData

makedocs(
    modules = [DynamicGrids],
    sitename = "DynamicGrids.jl",
)

deploydocs(
    repo = "github.com/cesaraustralia/DynamicGrids.jl.git",
)
