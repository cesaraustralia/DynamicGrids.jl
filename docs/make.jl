using Documenter, Cellular, Gtk, Plots, FileIO
using Cellular: rule, broadcast_rules!, neighbors, inhood, inbounds, process_image, resume!, replay, savegif, show_frame

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
