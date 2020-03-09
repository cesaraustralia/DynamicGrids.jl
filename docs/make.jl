using Documenter, DynamicGrids
using DynamicGrids: @Output, @Graphic, @Image, applyrule, applyrule!

makedocs(
    modules = [DynamicGrids],
    sitename = "DynamicGrids.jl",
)

deploydocs(
    repo = "github.com/cesaraustralia/DynamicGrids.jl.git",
)
