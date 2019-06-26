using Documenter, CellularAutomataBase, Gtk, Plots, FileIO, Mux, Blink
using CellularAutomataBase: rule, rule!, run_model!, run_rule!, max_radius, radius, 
      temp_neighborhood, neighbors, inhood, inbounds, process_frame

makedocs(
    modules = [CellularAutomataBase],
    sitename = "CellularAutomataBase.jl",
)

deploydocs(
    repo = "github.com/rafaqz/CellularAutomataBase.jl.git",
)
