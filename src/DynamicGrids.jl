module DynamicGrids
# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    # Use [`XX`](@ref) in the docs but not the readme
    text = replace(read(path, String), r"`(\w+\w)`" => s"[`\1`](@ref)")
    # Run examples
    replace(text, "```julia" => "```@example")
end DynamicGrids

using Colors,
      ConstructionBase,
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


export sim!, resume!, replay, savegif

export Rule, NeighborhoodRule, CellRule, PartialRule, PartialNeighborhoodRule

export Chain, Map, Life

export AbstractRuleset, Ruleset

export Neighborhood, AbstractRadialNeighborhood, RadialNeighborhood,
       AbstractCustomNeighborhood, CustomNeighborhood, LayeredCustomNeighborhood,
       VonNeumannNeighborhood

export PerformanceOpt, NoOpt, SparseOpt

export Overflow, RemoveOverflow, WrapOverflow

export Output, GraphicOutput, ImageOutput, ArrayOutput, REPLOutput

export GridProcessor, SingleGridProcessor, ColorProcessor, SparseOptInspector,
       MultiGridProcessor, ThreeColorProcessor, LayoutProcessor

export Greyscale, Grayscale

export CharStyle, Block, Braile


const FIELDDOCTABLE = FieldDocTable((:Description, :Default, :Limits),
                                    (description, default, limits);
                                    truncation=(100,40,100))

# Documentation templates
@template TYPES =
    """
    $(TYPEDEF)
    $(DOCSTRING)
    """

include("rules.jl")
include("chain.jl")
include("rulesets.jl")
include("simulationdata.jl")
include("outputs/output.jl")
include("outputs/graphic.jl")
include("outputs/image.jl")
include("outputs/array.jl")
include("outputs/repl.jl")
include("interface.jl")
include("framework.jl")
include("sequencerules.jl")
include("maprules.jl")
include("neighborhoods.jl")
include("utils.jl")
include("life.jl")

end
