module DynamicGrids
# Use the README as the module docs
@doc let 
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    # Use [`XX`](@ref) in the docs but not the readme
    text = replace(read(path, String), r"`(\w+\w)`" => s"[`\1`](@ref)")
    # Use doctests
    replace(text, "```julia" => "```jldoctest")
end DynamicGrids

using Colors,
      ColorSchemes,
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


export sim!, resume!, replay

export savegif, show_frame, ruletypes

export distances, broadcastable_indices, sizefromradius

export AbstractSimData, SimData, MultiSimData

export Rule, PartialRule, NeighborhoodRule, PartialNeighborhoodRule, CellRule, Chain

export Interaction, NeighborhoodInteraction, CellInteraction,
       PartialInteraction, PartialNeighborhoodInteraction

export AbstractRuleset, Ruleset, MultiRuleset

export Life

export Neighborhood, AbstractRadialNeighborhood, RadialNeighborhood, 
       AbstractCustomNeighborhood, CustomNeighborhood, LayeredCustomNeighborhood, 
       VonNeumannNeighborhood

export RemoveOverflow, WrapOverflow

export Output, GraphicOutput, ImageOutput, ArrayOutput, REPLOutput

export FrameProcessor, ColorProcessor, Greyscale, Grayscale

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
include("interactions.jl")
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
include("mapinteractions.jl")
include("neighborhoods.jl")
include("utils.jl")
include("life.jl")

end
