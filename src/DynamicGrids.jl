module DynamicGrids
# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end DynamicGrids


using Adapt,
      Colors,
      ConstructionBase,
      Crayons,
      DimensionalData,
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

export sim!, resume!, step!, savegif, isinferred

export rules, neighbors, neighborhood, offsets, positions, radius, inbounds, isinbounds 

export gridsize, currentframe, currenttime, currenttimestep, timestep

export add!, sub!, min!, max!, and!, or!, xor!

export Rule, NeighborhoodRule, CellRule, SetCellRule, SetNeighborhoodRule, SetGridRule

export Cell, Neighbors, SetNeighbors, SetCell, Convolution, SetGrid, Life, CopyTo

export Chain 

export AbstractRuleset, Ruleset, StaticRuleset

export Neighborhood, RadialNeighborhood, Window, AbstractKernel, Kernel,
       Moore, AbstractPositional, Positional, VonNeumann, LayeredPositional

export Processor, SingleCPU, ThreadedCPU

export PerformanceOpt, NoOpt, SparseOpt

export BoundaryCondition, Remove, Wrap

export ParameterSource, Aux, Grid

export Output, GraphicOutput, ImageOutput, ArrayOutput, ResultOutput, REPLOutput, GifOutput

export ImageGenerator, Image, Layout, SparseOptInspector

export TextConfig

export ObjectScheme, Greyscale, Grayscale

export CharStyle, Block, Braile

function __init__()
    global terminal
    terminal = REPL.Terminals.TTYTerminal(get(ENV, "TERM", Base.Sys.iswindows() ? "" : "dumb"), stdin, stdout, stderr)

    @require KernelAbstractions = "63c18a36-062a-441e-b654-da1e3ab1ce7c" include("cuda.jl")
end

include("interface.jl")
include("flags.jl")
include("neighborhoods.jl")
include("rules.jl")
include("rulesets.jl")
include("extent.jl")
include("grid.jl")
include("simulationdata.jl")
include("atomic.jl")
include("auxilary.jl")
include("chain.jl")
include("outputs/interface.jl")
include("outputs/output.jl")
include("outputs/graphic.jl")
include("outputs/image.jl")
include("outputs/textconfig.jl")
include("outputs/schemes.jl")
include("outputs/imagegenerators.jl")
include("outputs/array.jl")
include("outputs/repl.jl")
include("outputs/gif.jl")
include("framework.jl")
include("precalc.jl")
include("sequencerules.jl")
include("maprules.jl")
include("boundaries.jl")
include("utils.jl")
include("copyto.jl")
include("life.jl")
include("show.jl")

end
