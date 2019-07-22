abstract type AbstractSimData{T,N} <: AbstractArray{T,N} end

@mix struct SimDataMixin{T,N,I<:AbstractArray{T,N},S,St,Ra,Ru,Ti}
    init::I
    source::S
    dest::S
    sourcestatus::St
    deststatus::St
    radius::Ra
    ruleset::Ru
    t::Ti
end

(::Type{T})(data::AbstractSimData) where T <: AbstractSimData = 
    T(data.init, data.source, data.dest, data.sourcestatus, data.deststatus, data.radius, data.ruleset, data.t)

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
sourcestatus(d::AbstractSimData) = d.sourcestatus
deststatus(d::AbstractSimData) = d.deststatus
radius(d::AbstractSimData) = d.radius
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
swapsource(data) = begin
    SimData(init(data), dest(data), source(data), sourcestatus(data), 
            deststatus(data), radius(data), ruleset(data), currenttime(data))
end

"""
Uptate timestamp
"""
updatetime(data::SimData, t) = 
    SimData(init(data), source(data), dest(data), sourcestatus(data), 
            deststatus(data), radius(data), ruleset(data), t)

"""
Generate simulation data to match a ruleset and init array.
"""
simdata(ruleset::AbstractRuleset, init::AbstractArray) = begin
    r = maxradius(ruleset)
    if r > 0
        source = addpadding(init, r)
        sourcestatus = initstatus(parent(source), r) 
    else
        source = deepcopy(init)
        sourcestatus = true 
    end
    dest = deepcopy(source)
    deststatus = deepcopy(sourcestatus)

    SimData(init, source, dest, sourcestatus, deststatus, r, ruleset, 1)
end

"""
Find the maximum radius required by all rules
Add padding around the original init array, offset into the negative
So that the first real cell is still 1, 1
"""
addpadding(init::AbstractArray{T,N}, r) where {T,N} = begin
    sze = size(init)
    paddedsize = sze .+ 2r
    paddedindices = -r + 1:sze[1] + r, -r + 1:sze[2] + r
    source = OffsetArray(zeros(eltype(init), paddedsize...), paddedindices...)
    # Copy the init array to the middle section of the source array
    for j in 1:size(init, 2), i in 1:size(init, 1)
        source[i, j] = init[i, j]
    end
    source
end

"""
Initialise the block status array.
This tracks whether anything has to be done in an area of the main array.
"""
initstatus(source, r) = begin
    blocksize = 2r
    # We add one extra row/column so we dont have to worry about 
    # special casing the last block
    nblocs = indtoblock.(size(source), blocksize) .+ 1
    blockstatus = BitArray(zeros(Bool, nblocs))
    for i in CartesianIndices(source) 
        # Mark the status block if there is a non-zero value
        if source[i] != 0
            bi = indtoblock.(Tuple(i), blocksize)
            blockstatus[bi...] = true
        end
    end
    blockstatus
end

indtoblock(x, blocksize) = (x - 1) ÷ blocksize + 1
blocktoind(x, blocksize) = (x - 1) * blocksize + 1

Base.getindex(d::SimData, i...) = getindex(source(d), i...)

" Simulation data and storage is passed to rules for each timestep "
@SimDataMixin struct WritableSimData{} <: AbstractSimData{T,N} end

Base.@propagate_inbounds Base.setindex!(d::WritableSimData, x, i...) = begin
    r = radius(d)
    if r > 0
        bi = indtoblock.(i .+ r, 2r)
        deststatus(d)[bi...] = true
    end
    dest(d)[i...] = x
end
Base.getindex(d::WritableSimData, i...) = getindex(dest(d), i...)
