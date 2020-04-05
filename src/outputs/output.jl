
"""
All outputs must inherit from Output.

Simulation outputs are decoupled from simulation behaviour and in
many cases can be used interchangeably.
"""
abstract type Output{T} <: AbstractVector{T} end

# Generic ouput constructor. Converts an init array to vector of arrays.
(::Type{F})(init::AbstractMatrix; kwargs...) where F <: Output =
    F(; frames=[deepcopy(init)], kwargs...)
(::Type{F})(init::NamedTuple; kwargs...) where F <: Output =
    F(; frames=[deepcopy(init)], kwargs...)

(::Type{F})(o::T; kwargs...) where F <: Output where T <: Output =
    F(; frames=frames(o), starttime=starttime(o), stoptime=stoptime(o), kwargs...)

# Forward base methods to the frames array
Base.parent(o::Output) = frames(o)
Base.length(o::Output) = length(frames(o))
Base.size(o::Output) = size(frames(o))
Base.firstindex(o::Output) = firstindex(frames(o))
Base.lastindex(o::Output) = lastindex(frames(o))
Base.@propagate_inbounds Base.getindex(o::Output, i) =
    getindex(frames(o), i)
Base.@propagate_inbounds Base.setindex!(o::Output, x, i) = setindex!(frames(o), x, i)
Base.push!(o::Output, x) = push!(frames(o), x)
Base.append!(o::Output, x) = append!(frames(o), x)


"""
Mixin of basic fields for all outputs
"""
@premix @default_kw struct Output{T,A<:AbstractVector{T}}
    frames::A      | []
    running::Bool  | false
    starttime::Any | 1
    stoptime::Any  | 1
end

# Getters and setters
frames(o::Output) = o.frames
starttime(o::Output) = o.starttime
stoptime(o::Output) = o.stoptime
tspan(o::Output) = (stoptime(o), starttime(o))
isrunning(o::Output) = o.running
setrunning!(o::Output, val) = o.running = val
setstarttime!(output, x) = output.starttime = x
setstoptime!(output, x) = output.stoptime = x

# Placeholder methods for graphic functions that are
# ignored in simple outputs
settimestamp!(o::Output, f) = nothing
fps(o::Output) = nothing
setfps!(o::Output, x) = nothing
showfps(o::Output) = nothing

"""
    isasync(o::Output)

Check if the output should run asynchonously.
"""
isasync(o::Output) = false

"""
    isasync(o::Output)

Check if the output is storing each grid frame,
or just the the current one.
"""
isstored(o::Output) = true

"""
    isshowable(o::Output)

Check if the output can be shown visually.
"""
isshowable(o::Output, f) = false

"""
    initialise(o::Output)

Initialise the output display, if it has one.
"""
initialise(o::Output) = nothing
"""
    finalise(o::Output)

Finalise the output display, if it has one.
"""
finalise(o::Output) = nothing

"""
    delay(o::Output, f)

`Graphic` outputs delay the simulations to match some `fps` rate, 
but other outputs just do nothing and continue.
"""
delay(o::Output, f) = nothing
"""
    showgrid(o::Output, args...)

Show the grid(s) in the output, if it can do that.
"""
showgrid(o::Output, args...) = nothing


# Grid strorage and updating
frameindex(o::Output, data::AbstractSimData) = frameindex(o, currentframe(data))
# Every frame is frame 1 if the simulation isn't stored
frameindex(o::Output, f::Int) = isstored(o) ? f : oneunit(f)

zerogrids(init::AbstractArray, nframes) = [zero(init) for f in 1:nframes]
zerogrids(init::NamedTuple, nframes) =
    [map(layer -> zero(layer), init) for f in 1:nframes]


@inline celldo!(grid::GridData, A::AbstractArray, I) =
    @inbounds return A[I...] = source(grid)[I...]

storegrid!(output::Output, data::AbstractSimData) =
    storegrid!(output, data, frameindex(output, data))
storegrid!(output::Output, simdata::AbstractSimData, f::Int) = begin
    checkbounds(output, f)
    if eltype(output) <: NamedTuple
        map(values(grids(simdata)), keys(simdata)) do grid, key
            blockrun!(grid, output[f][key])
        end
    else
        blockrun!(first(grids(simdata)), output[f])
    end
end
# Replicated frames
storegrid!(output, data::AbstractVector{<:GridData}, f::Int) = begin
    for j in 1:size(output[1], 2), i in 1:size(output[1], 1)
        replicatesum = zero(eltype(output[1]))
        for d in data
            @inbounds replicatesum += d[i, j]
        end
        output[f][i, j] = replicatesum / length(data)
    end
end


allocategrids!(o::Output, init, framerange) = begin
    append!(frames(o), [similar(init) for f in framerange])
    o
end

"""
Grids are preallocated and reused.
"""
initgrids!(o::Output, init) = begin
    first(o) .= init
    for f = (firstindex(o) + 1):lastindex(o)
        @inbounds o[f] .= zero(eltype(init))
    end
    o
end
initgrids!(o::Output, init::NamedTuple) = begin
    for key in keys(init)
        first(o)[key] .= init[key]
    end
    for f = (firstindex(o) + 1):lastindex(o)
        for key in keys(init)
            @inbounds o[f][key] .= zero(eltype(init[key]))
        end
    end
    o
end
