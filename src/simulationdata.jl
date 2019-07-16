abstract type AbstractSimData{T,N} <: AbstractArray{T,N} end

@mix struct SimDataMixin{T,N,I<:AbstractArray{T,N},St,R,Ti}
    init::I
    source::St
    dest::St
    ruleset::R
    t::Ti
end

(::Type{T})(data::AbstractSimData) where T <: AbstractSimData = 
    T(data.init, data.source, data.dest, data.ruleset, data.t)

# Array interface
Base.length(d::AbstractSimData) = length(source(d))
Base.firstindex(d::AbstractSimData) = firstindex(source(d))
Base.lastindex(d::AbstractSimData) = lastindex(source(d))
Base.size(d::AbstractSimData) = size(source(d))
Base.broadcast(d::AbstractSimData, args...) = broadcast(source(d), args...)
Base.broadcast!(d::AbstractSimData, args...) = broadcast!(dest(d), args...)
Base.iterate(d::AbstractSimData, args...) = iterate(source(d), args...)
Base.ndims(::AbstractSimData{T,N}) where {T,N} = N
Base.eltype(::AbstractSimData{T}) where T = T

# Getters
init(d::AbstractSimData) = d.init
source(d::AbstractSimData) = d.source
dest(d::AbstractSimData) = d.dest
ruleset(d::AbstractSimData) = d.ruleset
currenttime(d::AbstractSimData) = d.t

framesize(d::AbstractSimData) = size(init(d))
mask(d::AbstractSimData) = mask(ruleset(d))
overflow(d::AbstractSimData) = overflow(ruleset(d))
timestep(d::AbstractSimData) = timestep(ruleset(d))
cellsize(d::AbstractSimData) = cellsize(ruleset(d))

" Simulation data and storage is passed to rules for each timestep "
@SimDataMixin struct SimData{} <: AbstractSimData{T,N} end

"""
Swap source and dest arrays. Allways returns regular SimData.
"""
swapsource(data) = SimData(init(data), dest(data), source(data), ruleset(data), currenttime(data))

"""
Uptate timestamp
"""
updatetime(data::SimData, t) = 
    SimData(init(data), source(data), dest(data), ruleset(data), t)

"""
Generate simulation data to match a ruleset and init array.
"""
simdata(ruleset::Ruleset, init::AbstractArray) = begin
    r = maxradius(ruleset)
    # Find the maximum radius required by all rules
    sze = size(init)
    newsize = sze .+ 2r
    # Add a margin around the original init array, offset into the negative
    # So that the first real cell is still 1, 1
    newindices = -r + 1:sze[1] + r, -r + 1:sze[2] + r
    source = OffsetArray(zeros(eltype(init), newsize...), newindices...)

    # Copy the init array to the middle section of the source array
    for j in 1:sze[2], i in 1:sze[1]
        source[i, j] = init[i,j]
    end
    # The dest array is the same as the source array
    dest = deepcopy(source)

    SimData(init, source, dest, ruleset, 1)
end

Base.getindex(d::SimData, i...) = getindex(source(d), i...)

" Simulation data and storage is passed to rules for each timestep "
@SimDataMixin struct WritableSimData{} <: AbstractSimData{T,N} end

Base.setindex!(d::WritableSimData, x, i...) = setindex!(dest(d), x, i...)
Base.getindex(d::WritableSimData, i...) = getindex(dest(d), i...)
