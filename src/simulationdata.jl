abstract type AbstractSimData end

abstract type AbstractSingleSimData{T,N,I} <: AbstractSimData end

@mix struct SimDataMixin{T,N,I<:AbstractArray{T,N},S,St,LSt,B,Ra,Ru,STi,CTi,CFr}
    init::I
    source::S
    dest::S
    sourcestatus::St
    deststatus::St
    localstatus::LSt
    buffers::B
    radius::Ra
    ruleset::Ru
    starttime::STi
    currenttime::CTi
    currentframe::CFr
end

SimDataOrReps = Union{AbstractSimData, Vector{<:AbstractSimData}}

(::Type{T})(data::AbstractSimData) where T <: AbstractSimData =
    T(init(data), source(data), dest(data), sourcestatus(data), deststatus(data),
      localstatus(data), buffers(data), radius(data), ruleset(data), starttime(data),
      currenttime(data), currentframe(data))

# Array interface
Base.length(d::AbstractSingleSimData) = length(source(d))
Base.firstindex(d::AbstractSingleSimData) = firstindex(source(d))
Base.lastindex(d::AbstractSingleSimData) = lastindex(source(d))
Base.size(d::AbstractSingleSimData) = size(source(d))
Base.broadcast(d::AbstractSingleSimData, args...) = broadcast(source(d), args...)
Base.broadcast!(d::AbstractSingleSimData, args...) = broadcast!(dest(d), args...)
Base.iterate(d::AbstractSingleSimData, args...) = iterate(source(d), args...)
Base.ndims(::AbstractSingleSimData{T,N}) where {T,N} = N
Base.eltype(::AbstractSingleSimData{T}) where T = T

# Getters
init(d::AbstractSingleSimData) = d.init
source(d::AbstractSingleSimData) = d.source
dest(d::AbstractSingleSimData) = d.dest
sourcestatus(d::AbstractSingleSimData) = d.sourcestatus
deststatus(d::AbstractSingleSimData) = d.deststatus
localstatus(d::AbstractSingleSimData) = d.localstatus
buffers(d::AbstractSingleSimData) = d.buffers
radius(d::AbstractSingleSimData) = d.radius
ruleset(d::AbstractSingleSimData) = d.ruleset
starttime(d::AbstractSingleSimData) = d.starttime
currenttime(d::AbstractSingleSimData) = d.currenttime
currentframe(d::AbstractSingleSimData) = d.currentframe


# Getters forwarded to ruleset
framesize(d::AbstractSingleSimData) = size(init(d))
rules(d::AbstractSingleSimData) = rules(ruleset(d))
mask(d::AbstractSingleSimData) = mask(ruleset(d))
overflow(d::AbstractSingleSimData) = overflow(ruleset(d))
timestep(d::AbstractSingleSimData) = timestep(ruleset(d))
cellsize(d::AbstractSingleSimData) = cellsize(ruleset(d))

"""
Get the actual current timestep, ie. not variable periods like Month
"""
currenttimestep(d::AbstractSimData) = currenttime(d) + timestep(d) - currenttime(d)

" Simulation data and storage is passed to rules for each timestep "
@SimDataMixin struct SimData{} <: AbstractSingleSimData{T,N,I} end

ConstructionBase.constructorof(::Type{SimData}) =
    (init, args...) -> SimData{eltype(init),ndims(init),typeof(init),typeof.(args)...}(init, args...)

"""
Generate simulation data to match a ruleset and init array.
"""
SimData(ruleset::Ruleset, init::AbstractArray, starttime, r=maxradius(ruleset)) = begin
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

        buffers = [zeros(eltype(init), hoodsize, hoodsize) for i in 1:blocksize]
        localstatus = zeros(Bool, 2, 2)
    else
        source = deepcopy(init)
        sourcestatus = deststatus = true
        buffers = nothing
        localstatus = nothing
    end
    dest = deepcopy(source)
    currentframe = 1
    currenttime = starttime

    SimData(init, source, dest, sourcestatus, deststatus, localstatus, buffers, r,
            ruleset, starttime, currenttime, currentframe)
end


"""
MultipleSimData is used for MultiRuleset models
"""
struct MultiSimData{I,D<:NamedTuple,Ru} <: AbstractSimData
    init::I
    data::D
    ruleset::Ru
end

data(d::MultiSimData) = d.data
ruleset(d::MultiSimData) = d.ruleset
framesize(d::MultiSimData) = framesize(first(data(d)))
interactions(d::MultiSimData) = interactions(ruleset(d))

Base.getindex(d::MultiSimData, key) = begin
    getindex(data(d), key)
end
Base.keys(d::MultiSimData) = keys(data(d))

# Getters
init(d::MultiSimData) = d.init
ruleset(d::MultiSimData) = d.ruleset
data(d::MultiSimData) = d.data

firstruleset(d::MultiSimData) = first(ruleset(ruleset(d)))
firstdata(d::MultiSimData) = first(data(d))
source(d::MultiSimData) = firstdata(d).source
dest(d::MultiSimData) = firstdata(d).dest
sourcestatus(d::MultiSimData) = firstdata(d).sourcestatus
deststatus(d::MultiSimData) = firstdata(d).deststatus
localstatus(d::MultiSimData) = firstdata(d).localstatus
buffers(d::MultiSimData) = firstdata(d).buffers
radius(d::MultiSimData) = firstdata(d).radius
starttime(d::MultiSimData) = firstdata(d).starttime
currenttime(d::MultiSimData) = firstdata(d).currenttime
currentframe(d::MultiSimData) = firstdata(d).currentframe


# Getters forwarded to ruleset
framesize(d::MultiSimData) = size(first(init(d)))
# rules(d::MultiSimData) = map(rules, ruleset(d))
mask(d::MultiSimData) = mask(firstruleset(d))
overflow(d::MultiSimData) = overflow(firstruleset(d))
timestep(d::MultiSimData) = timestep(firstruleset(d))
cellsize(d::MultiSimData) = cellsize(firstruleset(d))

"""
Swap source and dest arrays. Allways returns regular SimData.
"""
swapsource(data::AbstractSingleSimData) = begin
    src = data.source
    dst = data.dest
    @set! data.dest = src
    @set data.source = dst
end
swapsource(d::MultiSimData) = @set d.data = map(swapsource, d.data)

"""
Uptate timestamp
"""
updatetime(data::SimData, f::Integer) = begin
    @set! data.currentframe = f
    @set data.currenttime = timefromframe(data, f)
end
updatetime(data::AbstractVector{<:SimData}, f) = updatetime.(data, f)
updatetime(multidata::MultiSimData, f) =
    @set multidata.data = map(d -> updatetime(d, f), data(multidata))

timefromframe(data::AbstractSimData, f) = starttime(data) + (f - 1) * timestep(data)

"""
Find the maximum radius required by all rules
Add padding around the original init array, offset into the negative
So that the first real cell is still 1, 1
"""
addpadding(init::AbstractArray{T,N}, r) where {T,N} = begin
    sze = size(init)
    paddedsize = sze .+ 2r
    paddedindices = -r + 1:sze[1] + r, -r + 1:sze[2] + r
    source = OffsetArray(similar(init, paddedsize...), paddedindices...)
    source .= zero(eltype(source))
    # Copy the init array to he middle section of the source array
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

# TODO document these behaviours
initdata!(data::AbstractSimData, ruleset, init::AbstractArray, starttime, nreplicates) =
    initdata!(data, ruleset, starttime)
initdata!(data::AbstractVector{<:AbstractSimData}, ruleset, init::AbstractArray, starttime, nreplicates::Integer) =
    map(d -> initdata!(d, ruleset, init, starttime, nreplicates), data)
initdata!(data::Nothing, ruleset::Ruleset, init, starttime, nreplicates::Nothing) =
    SimData(ruleset, init, starttime)
# initdata!(data::Nothing, ruleset::Ruleset, init, starttime, nreplicates::Integer) =
    # [SimData(ruleset, init, starttime) for r in 1:nreplicates]
initdata!(data::Nothing, multiruleset::MultiRuleset, init::NamedTuple, starttime, nreplicates::Nothing) = begin
    radii = NamedTuple{keys(init)}(maxradius(multiruleset))
    data = map((rs, ra, in) -> SimData(rs, in, starttime, ra), ruleset(multiruleset), radii, init) 
    MultiSimData(init, data, multiruleset)
end
# initdata!(multidata::MultiSimData, multiruleset::MultiRuleset, init, starttime, nreplicates::Nothing) =
    # MultiSimData(map((d, rs) -> initdata!(d, rs, starttime), data(MultiSimData), ruleset(multiruleset))),
                 # interactions(multiruleset))
initdata!(data::AbstractSimData, ruleset::Ruleset, starttime) = begin
    for j in 1:framesize(data)[2], i in 1:framesize(data)[1]
        @inbounds source(data)[i, j] = dest(data)[i, j] = init(data)[i, j]
    end
    updatestatus!(data)
    @set! data.ruleset = ruleset
    @set! data.starttime = starttime
    data
end

indtoblock(x, blocksize) = (x - 1) ÷ blocksize + 1
blocktoind(x, blocksize) = (x - 1) * blocksize + 1

Base.@propagate_inbounds Base.getindex(d::SimData, I...) = getindex(source(d), I...)

" Simulation data and storage is passed to rules for each timestep "
@SimDataMixin struct WritableSimData{} <: AbstractSingleSimData{T,N,I} end

ConstructionBase.constructorof(::Type{WritableSimData}) =
    (init, args...) -> SimData{eltype(init),ndims(init),typeof(init),typeof.(args)...}(init, args...)

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
