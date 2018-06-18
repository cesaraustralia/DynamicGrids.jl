using Documenter, Cellular
using Cellular: rule, broadcastrules!, neighbors, inhood, inbounds, process_image, 
                update_output 

makedocs(
    modules = [Cellular],
    doctest = false,
    clean = false,
    sitename = "Cellular.jl",
    format = :html,
    pages = Any[
        "Introduction" => "index.md",
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
