abstract type AbstractSimData{T,N} end

"""
    buffer(data) 
Provides a buffer matching the neighborhood size
for all rules `<: AbstractNeighborhoodRule` 
"""
function buffer end

"""
    source(data) 
Provides the source array for all rule types.
"""
function source end

"""
    dest(data) 
Provides the source array for all rule types.
"""
function source end

"""
    overflow(data) 
Provides the overflow type for the simulation.
"""
function overflow end

" Simulation data and storage is passed to rules for each timestep "
struct SimData{T,N,I<:AbstractArray{T,N},St,B,Si,O,CS,TS,Ti} <: AbstractSimData{T,N}
    init::I
    source::St
    dest::St
    buffer::B
    size::Si
    overflow::O
    cellsize::CS
    timestep::TS
    t::Ti
end

# Some base methods to get info about the array
Base.ndims(::SimData{T,N}) where {T,N} = N
Base.eltype(::SimData{T}) where T = T
Base.size(d::SimData) = d.size

source(d::SimData) = d.source
dest(d::SimData) = d.dest
timestep(d::SimData) = d.timestep
cellsize(d::SimData) = d.cellsize
init(d::SimData) = d.init
buffer(d::SimData) = d.buffer
t(d::SimData) = d.t
overflow(d::SimData) = d.overflow

swapsource(data::SimData) = 
    SimData(data.init, data.dest, data.source, data.buffer, data.size, 
            data.overflow, data.cellsize, data.timestep, data.t)

newbuffer(data::SimData, buffer) = 
    SimData(data.init, data.source, data.dest, buffer, data.size, 
            data.overflow, data.cellsize, data.timestep, data.t)

simdata(model::Ruleset, source, dest, sze, t) = 
    SimData(model.init, source, dest, model.init, sze, 
            model.overflow, model.cellsize, model.timestep, t)
