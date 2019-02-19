"""
Cellular provides a framework for building grid based simulations. Everything
can be customised and added to, but there are some central idea that define how a Cellular
simulation works: *models*, *rules* and *neighborhoods*. For input and output of data there
are *init* arrays and *outputs*.

Models hold the configuration for a simulation, and trigger a specific `rule` method
that operates on each of the cells in the grid. See [`AbstractModel`](@ref) and
[`rule`](@ref). Models come in a number of flavours, which allows assumptions to be made that
can greatly improve performance.

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

For better performance, models included in a tuple will be combined into a single model 
(with only one array write). This is limited to [`AbstractCellModel`](@ref), although 
[`AbstractNeighborhoodModel`](@ref) may be used as the first model in the tuple.

```julia
sim!(output, Models(model1, (model2, model3)), init)
```
"""
module Cellular

using FieldDefaults,
      FielddocTables,
      Mixers,
      Requires,
      DocStringExtensions,
      OffsetArrays,
      UnicodeGraphics,
      REPLGamesBase,
      FieldMetadata,
      Images,
      Gtk,
      Cairo,
      FileIO

using Base: tail
using Lazy: @forward

import Base: show, getindex, setindex!, lastindex, size, length, push!, append!, broadcast, broadcast!, similar, eltype

import FieldMetadata: @description, description, @limits, limits, @flattenable, flattenable, default



export sim!, resume!, replay

export savegif, show_frame

export distances, broadcastable_indices

export AbstractModel, AbstractPartialModel,
       AbstractNeighborhoodModel, AbstractPartialNeighborhoodModel,
       AbstractCellModel

export Models # TODO: a real name for this

export AbstractLife, Life

export AbstractNeighborhood, AbstractRadialNeighborhood, RadialNeighborhood,
       AbstractCustomNeighborhood, CustomNeighborhood, MultiCustomNeighborhood

export AbstractOverflow, Skip, Wrap

export AbstractOutput, AbstractArrayOutput, ArrayOutput, GtkOutput, REPLOutput

export AbstractFrameProcessor, Greyscale, ColorZeros


const FIELDDOCTABLE = FielddocTable((:Description, :Default, :Limits), 
                                    (description, default, limits);
                                    truncation=(100,40,100))

# Documentation templates
@template TYPES =
    """
    $(TYPEDEF)
    $(DOCSTRING)
    $(METHODLIST)
    """

include("outputs/common.jl")
include("types.jl")
include("framework.jl")
include("neighborhoods.jl")
include("utils.jl")
include("life.jl")
include("outputs/image_processing.jl")
include("outputs/repl.jl")
include("outputs/gtk.jl")
include("outputs/array.jl")
include("outputs/sensitivity.jl")


function __init__()
    @require Blink="ad839575-38b3-5650-b840-f874b8c74a25" begin
        export BlinkOutput
        include("outputs/web.jl")
        include("outputs/blink.jl")
        @require Revise="295af30f-e4ad-537b-8983-00126c2a3abe" begin
            import .Revise
            Revise.add_file(Cellular, "src/outputs/web.jl")
            Revise.add_file(Cellular, "src/outputs/blink.jl")
        end
    end

    @require Mux="a975b10e-0019-58db-a62f-e48ff68538c9" begin
        export MuxOutput
        include("outputs/web.jl")
        include("outputs/mux.jl")
        @require Revise="295af30f-e4ad-537b-8983-00126c2a3abe" begin
            import .Revise
            Revise.add_file(Cellular, "src/outputs/web.jl")
            Revise.add_file(Cellular, "src/outputs/mux.jl")
        end
    end
end


end
