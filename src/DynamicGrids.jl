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
      Requires,
      Setfield,
      StaticArrays,
      Test,
      UnicodeGraphics

@reexport using ModelParameters

const DG = DynamicGrids
const DD = DimensionalData

using Base: tail, @propagate_inbounds

import Base: show, getindex, setindex!, lastindex, size, length, push!, append!,
             broadcast, broadcast!, similar, eltype, iterate

export sim!, resume!, savegif, isinferred

export rules, neighbors, neighborhood, offsets, positions, radius, inbounds, isinbounds 

export gridsize, currentframe, currenttime, currenttimestep, timestep

export add!, sub!, min!, max!, and!, or!, xor!

export Rule, NeighborhoodRule, CellRule, SetCellRule, SetNeighborhoodRule, SetGridRule

export Cell, Neighbors, SetNeighbors, SetCell, Convolution, SetGrid, Life, CopyTo

export Chain 

export AbstractRuleset, Ruleset, StaticRuleset

export Neighborhood, RadialNeighborhood, AbstractWindow, Window, AbstractKernel, Kernel,
       Moore, AbstractPositional, Positional, VonNeumann, LayeredPositional

export Processor, SingleCPU, ThreadedCPU

export PerformanceOpt, NoOpt, SparseOpt

export Boundary, Remove, Wrap

export Aux, Grid

export Output, GraphicOutput, ImageOutput, ArrayOutput, ResultOutput, REPLOutput, GifOutput

export GridProcessor, SingleGridProcessor, ColorProcessor, SparseOptInspector,
       MultiGridProcessor, LayoutProcessor

export TextConfig

export Greyscale, Grayscale

export CharStyle, Block, Braile

function __init__()
    global terminal
    terminal = REPL.Terminals.TTYTerminal(get(ENV, "TERM", Base.Sys.iswindows() ? "" : "dumb"), stdin, stdout, stderr)

    @require KernelAbstractions = "63c18a36-062a-441e-b654-da1e3ab1ce7c" include("cuda.jl")
end

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
include("aux.jl")
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
include("boundaries.jl")
include("utils.jl")
include("life.jl")
include("show.jl")

end
