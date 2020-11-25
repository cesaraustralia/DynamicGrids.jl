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
      FreeTypeAbstraction,
      FileIO,
      LinearAlgebra,
      OffsetArrays,
      REPL,
      Reexport,
      Setfield,
      StaticArrays,
      Test,
      UnicodeGraphics

@reexport using ModelParameters

const DG = DynamicGrids

using Base: tail, @propagate_inbounds

import Base: show, getindex, setindex!, lastindex, size, length, push!, append!,
             broadcast, broadcast!, similar, eltype, iterate

export sim!, resume!, savegif, isinferred, isinferred

export rules, neighbors, offsets, positions, radius, inbounds, isinbounds 

export gridsize, currenttime, currenttimestep, timestep

export add!, sub!, min!, max!, and!, or!, xor!

export Rule, NeighborhoodRule, CellRule, ManualRule, ManualNeighborhoodRule, GridRule

export Cell, Neighbors, SetNeighbors, Convolution, Manual, Chain, Life, Grid 

export AbstractRuleset, Ruleset, StaticRuleset

export Neighborhood, RadialNeighborhood, AbstractKernel, Kernel, Moore,
       AbstractPositional, Positional, VonNeumann, LayeredPositional

export Processor, SingleCPU, ThreadedCPU

export PerformanceOpt, NoOpt, SparseOpt

export Overflow, RemoveOverflow, WrapOverflow

export Output, GraphicOutput, ImageOutput, ArrayOutput, ResultOutput, REPLOutput, GifOutput

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

include("neighborhoods.jl")
include("rules.jl")
include("flags.jl")
include("rulesets.jl")
include("extent.jl")
include("grid.jl")
include("simulationdata.jl")
include("chain.jl")
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
