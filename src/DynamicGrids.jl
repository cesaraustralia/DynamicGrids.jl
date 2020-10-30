module DynamicGrids
# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    # Run examples
    replace(read(path, String), "```julia" => "```@example")
end DynamicGrids


using Colors,
      ConstructionBase,
      Crayons,
      DimensionalData,
      DocStringExtensions,
      ModelParameters,
      FreeTypeAbstraction,
      FileIO,
      OffsetArrays,
      REPL,
      Setfield,
      Test,
      UnicodeGraphics

const DG = DynamicGrids

using Base: tail

import Base: show, getindex, setindex!, lastindex, size, length, push!, append!,
             broadcast, broadcast!, similar, eltype, iterate

export sim!, resume!, savegif, isinferred, isinferred

export rules, neighbors, inbounds, isinbounds, radius, gridsize,
       currenttime, currenttimestep, timestep

export Rule, NeighborhoodRule, CellRule, ManualRule, ManualNeighborhoodRule

export Chain, Cell, Neighbors, Manual, Life

export AbstractRuleset, Ruleset

export Neighborhood, AbstractRadialNeighborhood, Moore,
       AbstractPositional, Positional, VonNeumann, LayeredPositional

export PerformanceOpt, NoOpt, SparseOpt

export Overflow, RemoveOverflow, WrapOverflow

export Output, GraphicOutput, ImageOutput, ArrayOutput, REPLOutput, GifOutput

export GridProcessor, SingleGridProcessor, ColorProcessor, SparseOptInspector,
       MultiGridProcessor, ThreeColorProcessor, LayoutProcessor

export TextConfig

export Greyscale, Grayscale

export CharStyle, Block, Braile

# Documentation templates
@template TYPES =
    """
    $(TYPEDEF)
    $(DOCSTRING)
    """

include("rules.jl")
include("rulesets.jl")
include("extent.jl")
include("simulationdata.jl")
include("chain.jl")
include("neighborhoods.jl")
include("outputs/output.jl")
include("outputs/graphic.jl")
include("outputs/image.jl")
include("outputs/textconfig.jl")
include("outputs/processors.jl")
include("outputs/array.jl")
include("outputs/repl.jl")
include("outputs/gif.jl")
include("interface.jl")
include("framework.jl")
include("precalc.jl")
include("sequencerules.jl")
include("maprules.jl")
include("overflow.jl")
include("utils.jl")
include("life.jl")
include("show.jl")

end
