"""
    AbstractSimSettings

Abstract supertype for [`SimSettings`](@ref) object and variants.
"""
abstract type AbstractSimSettings end

"""
    SimSettings <: AbstractSimSettings

Holds settings for the simulation, inside a `Ruleset` or `SimData` object.
"""
Base.@kwdef struct SimSettings{B,P,O,C,T} <: AbstractSimSettings
    boundary::B = Remove()
    proc::P = SingleCPU()
    opt::O = NoOpt()
    cellsize::C = 1
    timestep::T = nothing
end

boundary(s::AbstractSimSettings) = s.boundary
proc(s::AbstractSimSettings) = s.proc
opt(s::AbstractSimSettings) = s.opt
cellsize(s::AbstractSimSettings) = s.cellsize
timestep(s::AbstractSimSettings) = s.timestep
