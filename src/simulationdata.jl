abstract type AbstractSimData{T,N} <: AbstractArray{T,N} end

@mix struct SimDataMixin{T,N,I<:AbstractArray{T,N},S,St,LSt,B,Ra,Ru,Ti}
    init::I
    source::S
    dest::S
    sourcestatus::St
    deststatus::St
    localstatus::LSt
    buffers::B
    radius::Ra
    ruleset::Ru
    t::Ti
end

(::Type{T})(data::AbstractSimData) where T <: AbstractSimData =
    T(data.init, data.source, data.dest, data.sourcestatus, data.deststatus,
      data.localstatus, data.buffers, data.radius, data.ruleset, data.t)

Setfield.constructor_of(::Type{T}) where T<:AbstractSimData = T

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
localstatus(d::AbstractSimData) = d.localstatus
buffers(d::AbstractSimData) = d.buffers
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
    src = data.source
    dst = data.dest
    @set! data.dest = src
    @set! data.source = dst
    data
end

"""
Uptate timestamp
"""
updatetime(data::SimData, t) = begin
    @set! data.t = t
    data
end
updatetime(data::AbstractVector{<:SimData}, t) = updatetime.(data, t)

"""
Generate simulation data to match a ruleset and init array.
"""
simdata(ruleset::AbstractRuleset, init::AbstractArray) = begin
    r = maxradius(ruleset)
    # We add one extra row/column so we dont have to worry about
    # special casing the last block
    if r > 0
        hoodsize = 2r + 1
        blocksize = 2r
        source = addpadding(init, r)
        nblocs = indtoblock.(size(source), blocksize) .+ 1
        sourcestatus = BitArray(zeros(Bool, nblocs))
        deststatus = deepcopy(sourcestatus)
        updatestatus!(parent(source), sourcestatus, deststatus, r)

        buffers = typeof(init)[zeros(eltype(init), hoodsize, hoodsize) for i in 1:blocksize]
        localstatus = zeros(Bool, 2, 2)
    else
        source = deepcopy(init)
        sourcestatus = deststatus = true
        buffers = nothing
        localstatus = nothing
    end
    dest = deepcopy(source)

    SimData(init, source, dest, sourcestatus, deststatus, localstatus, buffers, r, ruleset, 1)
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
updatestatus!(data) = updatestatus!(parent(source(data)), sourcestatus(data), deststatus(data), radius(data))
updatestatus!(source, sourcestatus::Bool, deststatus::Bool, r) = nothing
updatestatus!(source, sourcestatus, deststatus, r) = begin
    blocksize = 2r
    source = parent(source)
    for i in CartesianIndices(source)
        # Mark the status block if there is a non-zero value
        if source[i] != 0
            bi = indtoblock.(Tuple(i), blocksize)
            sourcestatus[bi...] = true
            deststatus[bi...] = true
        end
    end
end

initdata!(data::AbstractSimData) = begin
    for j in 1:framesize(data)[2], i in 1:framesize(data)[1]
        @inbounds source(data)[i, j] = dest(data)[i, j] = init(data)[i, j]
    end
    updatestatus!(data)
    data
end
initdata!(data::AbstractSimData, ruleset, init, nreplicates) = initdata!(data)
initdata!(data::AbstractVector{<:AbstractSimData}, ruleset, init, nreplicates::Integer) = initdata!.(data)
initdata!(data::Nothing, ruleset, init, nreplicates::Nothing) = simdata(ruleset, init)
initdata!(data::Nothing, ruleset, init, nreplicates::Integer) = [simdata(ruleset, init) for r in 1:nreplicates]

indtoblock(x, blocksize) = (x - 1) ÷ blocksize + 1
blocktoind(x, blocksize) = (x - 1) * blocksize + 1

Base.@propagate_inbounds Base.getindex(d::SimData, I...) = getindex(source(d), I...)

" Simulation data and storage is passed to rules for each timestep "
@SimDataMixin struct WritableSimData{} <: AbstractSimData{T,N} end

Base.@propagate_inbounds Base.setindex!(d::WritableSimData, x, I...) = begin
    r = radius(d)
    if r > 0
        bi = indtoblock.(I .+ r, 2r)
        deststatus(d)[bi...] = true
    end
    isnan(x) && error("NaN in setindex: ", (d, I)) 
    dest(d)[I...] = x
end
Base.@propagate_inbounds Base.getindex(d::WritableSimData, I...) = getindex(dest(d), I...)
