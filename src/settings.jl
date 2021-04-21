"""
    AbstractSimSettings

Abstract supertype for [`SimSettings`](@ref) object and variants.
"""
abstract type AbstractSimSettings end

"""
    SimSettings <: AbstractSimSettings

Holds settings for the simulation, in a `Ruleset` or `SimData` object.
"""
Base.@kwdef struct SimSettings{B,P,Op,C,T} <: AbstractSimSettings
    boundary::B = Remove()
    proc::P = SingleCPU()
    opt::Op = NoOpt()
    cellsize::C = 1
    timestep::T = nothing
end

boundary(s::AbstractSimSettings) = s.boundary
proc(s::AbstractSimSettings) = s.proc
opt(s::AbstractSimSettings) = s.opt
cellsize(s::AbstractSimSettings) = s.cellsize
timestep(s::AbstractSimSettings) = s.timestep
