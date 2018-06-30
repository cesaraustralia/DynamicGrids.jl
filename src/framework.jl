"""
A model contains all the data required to run a rule in a cellular 
simulation. Models can be chained together in any order.

The output of the rule for an AbstractModel is written to the current cell in the grid.
"""
abstract type AbstractModel end

"""
An abstract type for models that do not write to every cell of the grid (for efficiency).

There are two main differences with `AbstractModel`. AbstractPartialModel requires
initialisation of the destination array before each timestep, and the output of 
the rule is not written to the grid but done manually.
"""
abstract type AbstractPartialModel end


""" 
$(SIGNATURES)
Runs the whole simulation, passing the destination aray to 
the passed in output for each time-step.

### Arguments
- output: Any [AbstractOutput](@ref) to save frames to or display on the screen.
- model: A single mode ([`AbstractModel`](@ref)) or a tuple of models.
- init: Initialisation array. 
- args: Any additional user defined args are passed through to [`rule`](@ref) and 
  [`neighbors`](@ref) methods.

### Keyword Arguments
- time: Any Iterable of Number. Default is 1:1000
- pause: A Number, pauses beteen frames. Default is 0.0.
"""
sim!(output, model, init, args...; time=1:1000, pause=0.0) = begin
    # Initialise arrays to the same type and values as the passed in initial array
    source = deepcopy(init)
    dest = deepcopy(init)
    # Loop over the selected timespanb
    for t in time
        # Send the current grid to the output for display, records, etc.
        update_output(output, source, t, pause) || break
        # Run the automation on the source array, writing to the dest array and 
        # setting the source and dest arrays for the next iteration.
        source, dest = automate!(model, source, dest, t, args...) 
    end
    output
end

""" 
    automate!(models::Tuple, source, dest, t, args...) = begin
Runs the rules over the whole grid, for each module in sequence.
"""
automate!(models::Tuple, source, dest, t, args...) = begin
    width, height = size(source)
    # Define the index coordinates. There might be a better way than this?
    index = collect((col,row) for col in 1:width, row in 1:height)
    # Run the kernel for every cell, the result sets the dest cell
    broadcastrules!(models, source, dest, index, t, args...)
end 
automate!(model, source, dest, args...) = automate!((model,), source, dest, args...)


""" 
    broadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractModel}
Broadcast rule over each cell in the grid, for each module. 
Returned values are written to the `dest` grid.
"""
broadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractModel} = begin
    # Write rule outputs to every cell of the dest array
    broadcast!(rule, dest, models[1], source, index, t, (source,), (dest,), args...)
    # Swap source and dest for the next rule/iteration
    broadcastrules!(Base.tail(models), dest, source, index, t, args...) 
end

""" 
    broadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractPartialModel}
[`AbstractPartialModel`](@ref) Broadcasts rules for each cell in the grid, for each module. 
Rules must manually write to the `source` array. return values are ignored.
"""
broadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractPartialModel} = begin
    # Initialise the dest array
    fill!(dest, zero(eltype(dest)))
    # The rule writes to the dest array manually where required
    broadcast(rule, models[1], source, index, t, (source,), (dest,), args...)
    # Swap source and dest for the next rule/iteration
    broadcastrules!(Base.tail(models), dest, source, index, t, args...) 
end
broadcastrules!(models::Tuple{}, source, dest, index, t, args...) = source, dest


""" 
    function rule(model, state, index, t, source, dest, args...)
Rules for altering cell values.

### Arguments:
- `rule::AbstractModel`: 
- `state`: value of the current cell
- `index`: row, column coordinate tuple for the current cell
- `t`: current time step
- `source`: the whole source array
- `dest`: the whole destination array
- `args`: additional arguments passed through from user input to [`sim!`](@ref)

"""
function rule(model::Void, state, index, t, source, args...) end


""" 
Singleton types for choosing the grid overflow rule used in
[`inbounds`](@ref). These determine what is done when a neighborhood 
or jump extends outside of the grid.
"""
abstract type AbstractOverflow end 

"Wrap cords that overflow to the opposite side"
struct Wrap <: AbstractOverflow end

"Skip coords that overflow boundaries"
struct Skip <: AbstractOverflow end

"""
    inbounds(xs::Tuple, maxs::Tuple, overflow)
Check grid boundaries for two coordinates.

Returns a 3-tuple of co-ords and a boolean `true` if the cell is in bounds,
`false` if not.
"""
inbounds(xs::Tuple, maxs::Tuple, overflow) = begin
    a, inbounds_a = inbounds(xs[1], maxs[1], overflow)
    b, inbounds_b = inbounds(xs[2], maxs[2], overflow)
    a, b, inbounds_a && inbounds_b
end

"""
    inbounds(x::Number, max::Number, overflow::Skip)
Skip coordinates that overflow outside of the grid.

Returns a tuple of the position and `true` if it is inbounds, `false` if not.
"""
inbounds(x::Number, max::Number, overflow::Skip) = x, x > 0 && x <= max

"""
    inbounds(x::Number, max::Number, overflow::Skip)
Swap overflowing coordinates to the other side.

Returns a tuple with the position or it's wrapped equivalent, 
and `true` as it's allways in bounds.
"""
inbounds(x::Number, max::Number, overflow::Wrap) = begin
    if x < 1
        x = max + rem(x, max)
    elseif x > max
        x = rem(x, max)
    end
    x, true
end
