using Documenter, CellularAutomataBase

makedocs(
    modules = [CellularAutomataBase],
    sitename = "CellularAutomataBase.jl",
)

deploydocs(
    repo = "github.com/rafaqz/CellularAutomataBase.jl.git",
)
