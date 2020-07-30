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
      DimensionalData,
      DocStringExtensions,
      FieldDefaults,
      FieldMetadata,
      FieldDocTables,
      FreeTypeAbstraction,
      FileIO,
      Mixers,
      OffsetArrays,
      REPL,
      Setfield,
      Test,
      UnicodeGraphics

const DG = DynamicGrids

using Base: tail

import Base: show, getindex, setindex!, lastindex, size, length, push!, append!,
             broadcast, broadcast!, similar, eltype, iterate

import FieldMetadata: @description, description, 
                      @bounds, bounds,
                      @flattenable, flattenable,
                      @default, default


export sim!, resume!, replay, savegif, isinferred, method, methodtype, isinferred

export rules, neighbors, inbounds, isinbounds, radius, gridsize, 
       currenttime, currenttimestep, timestep

export Rule, NeighborhoodRule, CellRule, ManualRule, ManualNeighborhoodRule

export Chain, Cell, Neighbors, Manual, Map, Life

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


const FIELDDOCTABLE = FieldDocTable((:Description, :Default, :Bounds),
                                    (description, default, bounds);
                                    truncation=(100,40,100))

include("rules.jl")
include("rulesets.jl")
include("extent.jl")
include("simulationdata.jl")
include("chain.jl")
include("neighborhoods.jl")
include("outputs/output.jl")
include("outputs/graphic.jl")
include("outputs/image.jl")
include("outputs/array.jl")
include("outputs/repl.jl")
include("outputs/gif.jl")
include("interface.jl")
include("framework.jl")
include("sequencerules.jl")
include("maprules.jl")
include("overflow.jl")
include("utils.jl")
include("life.jl")
include("show.jl")

end
