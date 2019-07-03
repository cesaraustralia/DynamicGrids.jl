"""
CellularAutomataBase provides a framework for building grid based simulations. 

The framework is highly customisable, but there are some central idea that define 
how a Cellular simulation works: *rules*, and *neighborhoods*. 
For input and output of data there are *init* arrays and *outputs*.

Rules hold the configuration for a simulation, and trigger a specific `applyrule` method
that operates on each of the cells in the grid. See [`AbstractRule`](@ref) and
[`applyrule`](@ref). Rules come in a number of flavours, which allows assumptions to be made 
about running them that can greatly improve performance.

Outputs are ways of storing of viewing a simulation, and can be used interchangeably
depending on your needs. See [`AbstractOutput`](@ref).

The init array may be any AbstractArray, containing whatever initialisation data
is required to start the simulation.
A typical simulation is run with a script like:

```julia
init = my_array
rules = Ruleset(Life())
output = ArrayOutput(init)

sim!(output, rules; init=init)
```

Multiple models can be passed to `sim!()` in a `Ruleset()`. Each rule
will be run for the whole grid, in sequence.

```julia
sim!(output, Ruleset(rule1, rule2); init=init)
```

For better performance, models included in a tuple will be combined into a single model 
(with only one array write). This is limited to [`AbstractCellRule`](@ref), although 
[`AbstractNeighborhoodRule`](@ref) may be used as the *first* model in the tuple.

```julia
sim!(output, Rules(rule1, (rule2, rule3)); init=init)
```
"""
module CellularAutomataBase

using Colors, 
      Crayons,
      DocStringExtensions,
      FieldDefaults,
      FieldMetadata,
      FieldDocTables,
      FileIO,
      Mixers,
      OffsetArrays,
      REPL,
      UnicodeGraphics

using Base: tail
using Lazy: @forward

import Base: show, getindex, setindex!, lastindex, size, length, push!, append!, broadcast, broadcast!, similar, eltype

import FieldMetadata: @description, description, @limits, limits, @flattenable, flattenable, default



export sim!, resume!, replay

export savegif, show_frame

export distances, broadcastable_indices, sizefromradius 

export AbstractRule, AbstractPartialRule,
       AbstractNeighborhoodRule, AbstractPartialNeighborhoodRule, 
       AbstractCellRule

export AbstractRuleset, Ruleset

export AbstractLife, Life

export AbstractNeighborhood, RadialNeighborhood, AbstractCustomNeighborhood, 
       CustomNeighborhood, LayeredCustomNeighborhood, VonNeumannNeighborhood

export AbstractOverflow, RemoveOverflow, WrapOverflow

export AbstractOutput, AbstractArrayOutput, ArrayOutput, REPLOutput

export AbstractFrameProcessor, GreyscaleProcessor, GrayscaleProcessor, 
       GreyscaleZerosProcessor, GrayscaleZerosProcessor, 
       ColorSchemeProcessor, ColorSchemeZerosProcessor 

export AbstractSummary


const FIELDDOCTABLE = FieldDocTable((:Description, :Default, :Limits), 
                                    (description, default, limits);
                                    truncation=(100,40,100))

# Documentation templates
@template TYPES =
    """
    $(TYPEDEF)
    $(DOCSTRING)
    $(METHODLIST)
    """

include("types.jl")
include("outputs/common.jl")
include("simulationdata.jl")
include("interface.jl")
include("framework.jl")
include("neighborhoods.jl")
include("utils.jl")
include("life.jl")
include("outputs/frame_processing.jl")
include("outputs/array.jl")
include("outputs/repl.jl")

end
