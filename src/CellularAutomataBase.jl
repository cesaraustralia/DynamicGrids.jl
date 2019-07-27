"""
CellularAutomataBase provides a framework for building grid-based simulations.

The framework is highly customisable, but there are some central ideas that define
how a simulation works: *rules*, *init* arrays and *outputs*.

Rules hold the configuration for a simulation, and trigger a specific `applyrule` method
that operates on each of the cells in the grid. See [`AbstractRule`](@ref) and
[`applyrule`](@ref). Rules come in a number of flavours, which allows assumptions to be made
about running them that can greatly improve performance. Rules are chained together in
a [`Ruleset`](@ref) object.

The init array may be any AbstractArray, containing whatever initialisation data
is required to start the simulation. The Array type and element type of the init
array determine the types used in the simulation, as well as providing the initial conditions.

Outputs are ways of storing of viewing a simulation, and can be used interchangeably
depending on your needs. See [`AbstractOutput`](@ref).

A typical simulation is run with a script like:

```julia
init = my_array
rules = Ruleset(Life())
output = ArrayOutput(init)

sim!(output, rules; init=init)
```

Multiple models can be passed to [`sim!`](@ref) in a [`Ruleset`](@ref). Each rule
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
      Setfield,
      UnicodeGraphics

using Base: tail
using Lazy: @forward

import Base: show, getindex, setindex!, lastindex, size, length, push!, append!,
              broadcast, broadcast!, similar, eltype, iterate

import FieldMetadata: @description, description, @limits, limits,
                      @flattenable, flattenable, default


export sim!, resume!, replay

export savegif, show_frame, ruletypes

export distances, broadcastable_indices, sizefromradius

export AbstractRule, AbstractPartialRule,
       AbstractNeighborhoodRule, AbstractPartialNeighborhoodRule,
       AbstractCellRule

export AbstractRuleset, Ruleset

export AbstractLife, Life

export AbstractNeighborhood, RadialNeighborhood, AbstractCustomNeighborhood,
       CustomNeighborhood, LayeredCustomNeighborhood, VonNeumannNeighborhood

export RemoveOverflow, WrapOverflow

export AbstractOutput, AbstractGraphicOutput, AbstractImageOutput, AbstractArrayOutput, ArrayOutput, REPLOutput

export AbstractFrameProcessor, GreyscaleProcessor, GrayscaleProcessor,
       GreyscaleZerosProcessor, GrayscaleZerosProcessor,
       ColorSchemeProcessor, ColorSchemeZerosProcessor

export AbstractCharStyle, Block, Braile

export AbstractSummary


const FIELDDOCTABLE = FieldDocTable((:Description, :Default, :Limits),
                                    (description, default, limits);
                                    truncation=(100,40,100))

# Documentation templates
@template TYPES =
    """
    $(TYPEDEF)
    $(DOCSTRING)
    """

include("types.jl")
include("rulesets.jl")
include("simulationdata.jl")
include("outputs/common.jl")
include("interface.jl")
include("framework.jl")
include("maprules.jl")
include("neighborhoods.jl")
include("utils.jl")
include("life.jl")
include("outputs/frame_processing.jl")
include("outputs/array.jl")
include("outputs/repl.jl")

end
