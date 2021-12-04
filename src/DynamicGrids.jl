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
      KernelAbstractions,
      OffsetArrays,
      REPL,
      Reexport,
      Requires,
      Setfield,
      StaticArrays,
      Test,
      UnicodeGraphics

@reexport using ModelParameters

import ModelParameters.Flatten

using DimensionalData.LookupArrays, DimensionalData.Dimensions

const DG = DynamicGrids
const DD = DimensionalData

using Base: tail, @propagate_inbounds

import Base: show, getindex, setindex!, lastindex, size, length, push!, append!,
             broadcast, broadcast!, similar, eltype, iterate

export sim!, resume!, step!, savegif, isinferred

export rules, neighbors, neighborhood, kernel, kernelproduct, offsets, positions, radius 

export inbounds, isinbounds 

export gridsize, currentframe, currenttime, currenttimestep, timestep

export add!, sub!, min!, max!, and!, or!, xor!

export Rule, NeighborhoodRule, CellRule, SetCellRule, SetNeighborhoodRule, SetGridRule

export Cell, Neighbors, SetNeighbors, SetCell, Convolution, SetGrid, Life, CopyTo

export RuleWrapper, Chain, RunIf, RunAt

export AbstractRuleset, Ruleset, StaticRuleset

export AbstractSimData

export Neighborhood, RadialNeighborhood, Window, AbstractKernelNeighborhood, Kernel,
       Moore, AbstractPositionalNeighborhood, Positional, VonNeumann, LayeredPositional

export Processor, SingleCPU, ThreadedCPU, CPUGPU

export PerformanceOpt, NoOpt, SparseOpt

export BoundaryCondition, Remove, Wrap

export ParameterSource, Aux, Grid, Delay, Lag, Frame

export Output, ArrayOutput, ResultOutput, TransformedOutput

export GraphicOutput, REPLOutput

export ImageOutput, GifOutput

export Renderer, Image, Layout, SparseOptInspector

export TextConfig

export ObjectScheme, Greyscale, Grayscale

export CharStyle, Block, Braile


const DEFAULT_KEY = :_default_

const EXPERIMENTAL = """
        WARNING: This feature is experimental. It may change in future versions, 
        and may not be 100% reliable in all cases. Please file github issues if problems occur.
        """


function __init__()
    global terminal
    terminal = REPL.Terminals.TTYTerminal(get(ENV, "TERM", Base.Sys.iswindows() ? "" : "dumb"), stdin, stdout, stderr)

    @require CUDAKernels = "72cfdca4-0801-4ab0-bf6a-d52aa10adc57" include("cuda.jl")
end

include("interface.jl")
include("flags.jl")
include("neighborhoods.jl")
include("rules.jl")
include("settings.jl")
include("rulesets.jl")
include("extent.jl")
include("grid.jl")
include("simulationdata.jl")
include("parametersources.jl")
include("gpu.jl")
include("atomic.jl")
include("chain.jl")
include("condition.jl")
include("outputs/interface.jl")
include("outputs/output.jl")
include("outputs/graphic.jl")
include("outputs/image.jl")
include("outputs/textconfig.jl")
include("outputs/schemes.jl")
include("outputs/render.jl")
include("outputs/array.jl")
include("outputs/transformed.jl")
include("outputs/repl.jl")
include("outputs/gif.jl")
include("framework.jl")
include("modifyrule.jl")
include("sequencerules.jl")
include("generated.jl")
include("maprules.jl")
include("boundaries.jl")
include("sparseopt.jl")
include("utils.jl")
include("copyto.jl")
include("life.jl")
include("show.jl")

end
