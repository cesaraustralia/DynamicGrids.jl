"""
Cellular provides a framework for building grid based simulations. Everything
can be customised and added to, but there are some central idea that define how a Cellular
simulation works: *models*, *rules* and *neighborhoods*. For input and output of data their are
*init* arrays and *outputs*.

Models hold the configuration for a simulation, and trigger a specific `rule` method
that operates on each of the cells in the grid. See [`AbstractModel`](@ref) and
[`rule`](@ref). Rules often trigger [`neighbors`](@ref) methods that sum surrounding cell
*neighborhoods* ([`AbstractNeighborhood`](@ref)), such as Moore and Von Neumann neighborhoods.

Outputs are ways of storing of viewing the simulation, and can be used interchangeably
depending on your needs. See [`AbstractOutput`](@ref).

The inititialisation array may be any AbstractArray, containing whatever initialisation data
is required to start the simulation. Most rules work on two-dimensional arrays, but one-dimensional
arrays are also use for some cellular automata.

A typical simulation is run with a script like:

```julia
init = my_array
model = Models(Life())
output = REPLOutput(init)

sim!(output, model, init)
```

Multiple models can be passed to `sim!()` wrap in `Models()`, and each of their rules
will be run for the whole grid in sequence.

```julia
sim!(output, Models(model1, model2), init)
```
"""
module Cellular

using Parameters,
      Mixers,
      Requires,
      DocStringExtensions,
      UnicodeGraphics,
      REPLGamesBase,
      FieldMetadata,
      Gtk, 
      Cairo,
      FileIO

import Base: show, getindex, setindex!, lastindex, size, length, push!, append!
import Flatten: @flattenable, flattenable
import FieldMetadata: @limits, limits


export sim!,
       resume!,
       replay,
       savegif,
       show_frame,
       broadcastable_indices,
       distances,
       show, getindex, setindex!, lastindex, size, length, push!, append!,
       AbstractModel,
       AbstractPartialModel,
       AbstractLife,
       Life,
       AbstractNeighborhood,
       AbstractRadialNeighborhood,
       RadialNeighborhood,
       AbstractCustomNeighborhood,
       CustomNeighborhood,
       MultiCustomNeighborhood,
       AbstractOverflow,
       Models,
       Skip,
       Wrap,
       AbstractOutput,
       AbstractArrayOutput,
       ArrayOutput,
       GtkOutput,
       REPLOutput


# Documentation templates
@template TYPES =
    """
    $(TYPEDEF)
    $(DOCSTRING)
    $(FIELDS)
    """

include("outputs/common.jl")
include("types.jl")
include("framework.jl")
include("neighborhoods.jl")
include("utils.jl")
include("life.jl")
include("outputs/repl.jl")
include("outputs/gtk.jl")
include("outputs/array.jl")
include("outputs/sensitivity.jl")


function __init__()
    @require Plots="91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
        export PlotsOutput
        include("outputs/plots.jl")
    end

    @require Blink="ad839575-38b3-5650-b840-f874b8c74a25" begin
        export BlinkOutput
        include("outputs/web.jl")
        include("outputs/blink.jl")
    end

    @require Mux="a975b10e-0019-58db-a62f-e48ff68538c9" begin
        export MuxOutput
        include("outputs/web.jl")
        include("outputs/mux.jl")
    end
end

end
