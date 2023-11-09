"""
    AbstractSimSettings

Abstract supertype for [`SimSettings`](@ref) object and variants.
"""
abstract type AbstractSimSettings end

"""
    SimSettings <: AbstractSimSettings

Holds settings for the simulation, inside a `Ruleset` or `SimData` object.
"""
struct SimSettings{B,P,O,C,T} <: AbstractSimSettings
    boundary::B
    proc::P
    opt::O
    cellsize::C
    timestep::T
end
function SimSettings(;
    boundary=Remove(), proc=SingleCPU(), opt=NoOpt(), cellsize=1, timestep=nothing, kw...
)
    SimSettings(boundary, proc, opt, cellsize, timestep)
end

boundary(s::AbstractSimSettings) = s.boundary
proc(s::AbstractSimSettings) = s.proc
opt(s::AbstractSimSettings) = s.opt
cellsize(s::AbstractSimSettings) = s.cellsize
timestep(s::AbstractSimSettings) = s.timestep
