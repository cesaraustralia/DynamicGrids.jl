"""
    Output

Abstract supertype for simulation outputs.

Outputs are store or display simulation results, usually
as a vector of grids, one for each timestep - but they may also
sum, combine or otherwise manipulate the simulation grids to improve
performance, reduce memory overheads or similar.

Simulation outputs are decoupled from simulation behaviour,
and in many cases can be used interchangeably.
"""
abstract type Output{T,A} <: AbstractDimArray{T,1,Tuple{Ti},A} end
# Generic ImageOutput constructor. Converts an init array to vector of arrays.
function (::Type{T})(
    init::Union{NamedTuple,AbstractMatrix}; extent=nothing, kw...
) where T <: Output
    extent = extent isa Nothing ? Extent(; init=init, kw...) : extent
    T(; frames=[deepcopy(init)], running=false, extent=extent, kw...)
end

# Forward base methods to the frames array
Base.parent(o::Output) = frames(o)
Base.length(o::Output) = length(parent(o))
Base.size(o::Output) = size(parent(o))
Base.firstindex(o::Output) = firstindex(parent(o))
Base.lastindex(o::Output) = lastindex(parent(o))
Base.push!(o::Output, x) = push!(parent(o), x)
Base.step(o::Output) = step(tspan(o))

# DimensionalData interface
function DimensionalData.dims(o::Output)
    ts = tspan(o)
    val = isstored(o) ? ts : ts[end]:step(ts):ts[end]
    (Ti(val; mode=Sampled(Ordered(), Regular(step(ts)), Intervals(Start()))),)
end
DimensionalData.refdims(o::Output) = ()
DimensionalData.name(o::Output) = NoName()
DimensionalData.metadata(o::Output) = NoMetadata()
# Output bebuild just returns a DimArray
DimensionalData.rebuild(o::Output, data, dims::Tuple, refdims, name, metadata) = 
    DimArray(data, dims, refdims, name, metadata)

# Getters and setters
frames(o::Output) = o.frames
isrunning(o::Output) = o.running
extent(o::Output) = o.extent
init(o::Output) = init(extent(o))
mask(o::Output) = mask(extent(o))
aux(o::Output, key...) = aux(extent(o), key...)
tspan(o::Output) = tspan(extent(o))
timestep(o::Output) = step(tspan(o))

ruleset(o::Output) =
    throw(ArgumentError("No ruleset on the output. Pass one to `sim!` as the second argument"))
fps(o::Output) = nothing
stoppedframe(o::Output) = lastindex(o)

setrunning!(o::Output, val) = o.running = val
settspan!(o::Output, tspan) = settspan!(extent(o), tspan)
setfps!(o::Output, x) = nothing
settimestamp!(o::Output, f) = nothing
setstoppedframe!(o::Output, f) = nothing

isasync(o::Output) = false
isstored(o::Output) = true
isshowable(o::Output, frame) = false
initialise!(o::Output, data) = nothing
finalise!(o::Output, data) = nothing
initialisegraphics(o::Output, data) = nothing
finalisegraphics(o::Output, data) = nothing
delay(o::Output, frame) = nothing
showframe(o::Output, data) = nothing

frameindex(o::Output, data::AbstractSimData) = frameindex(o, currentframe(data))
frameindex(o::Output, f::Int) = isstored(o) ? f : oneunit(f)

function storeframe!(output::Output, data)
    checkbounds(output, frameindex(output, data))
    _storeframe!(eltype(output), output, data)
end

function _storeframe!(::Type{<:NamedTuple}, output::Output, data)
    map(values(grids(data)), keys(data)) do grid, key
        _copyto_output!(output[frameindex(output, data)][key], grid, proc(data))
    end
end
function _storeframe!(::Type{<:AbstractArray}, output::Output, data)
    grid = first(grids(data))
    _copyto_output!(output[frameindex(output, data)], grid, proc(data))
end

function _copyto_output!(outgrid, grid::GridData, proc)
    copyto!(outgrid, CartesianIndices(outgrid), source(grid), CartesianIndices(outgrid))
end
function _copyto_output!(outgrid, grid::GridData, proc::ThreadedCPU)
    Threads.@threads for j in axes(outgrid, 2) 
        for i in axes(outgrid, 1)
            @inbounds outgrid[i, j] = grid[i, j]
        end
    end
end

# Grids are preallocated and reused.
init_output_grids!(o::Output, init) = init_output_grids!(o[1], o::Output, init)
# Array grids are copied
function init_output_grids!(grid::AbstractArray, o::Output, init::AbstractArray)
    copyto!(grid, init)
    return o
end
# All arrays are copied if both are named tuples
function init_output_grids!(grids::NamedTuple, o::Output, inits::NamedTuple)
    map(grids, inits) do grid, init
        copyto!(grid, init)
    end
    return o
end
