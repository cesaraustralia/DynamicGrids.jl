using Documenter, Cellular, Gtk, Plots, FileIO, Mux, Blink
using Cellular: rule, rule!, run_model!, run_rule!, max_radius, radius, 
      temp_neighborhood, neighbors, inhood, inbounds, process_image

makedocs(
    modules = [Cellular],
    doctest = false,
    clean = false,
    sitename = "Cellular.jl",
    format = :html,
    pages = Any[
        "Cellular" => "index.md",
    ]
)

deploydocs(
    repo = "github.com/rafaqz/Cellular.jl.git",
    osname = "linux",
    julia = "0.6",
    target = "build",
    deps = nothing,
    make = nothing
)
