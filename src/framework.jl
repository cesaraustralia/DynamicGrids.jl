"""
A module contains all the data required to run a rule in a cellular 
simulation. Models can be chained together in any order or length.

The output of the rule for a default modules is written to the current cell in the grid.
"""
abstract type AbstractModel end

"""
The output of In-place modules is ignored, instead they manually update cells.
This is the best options for modules that only update a subset of cells.
"""
abstract type AbstractInPlaceModel end


""" 
Singleton for selection overflow rules. These determine what is 
done when a neighborhood or jump extends outside the grid.
"""
abstract type AbstractOverflow end

"""
    Wrap()
Wrap cords that overflow to the opposite side 
"""

struct Wrap <: AbstractOverflow end

"""
    Skip()
Skip coords that overflow boundaries 
"""
struct Skip <: AbstractOverflow end


""" 
$(SIGNATURES)
Runs the whole simulation, passing the destination aray to 
the passed in output for each time-step.

### Arguments
model: a single module or tuple of modules [`AbstractModel`](@ref)
"""
sim!(output, model, init, args...; time=1:10000, pause=0.0) = begin
    source = deepcopy(init)
    dest = deepcopy(init)
    for t in time
        update_output(output, source, t, pause) || break
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
    # Write output to dest array
    broadcast!(rule, dest, models[1], source, index, t, (source,), args...)
    # Swap source and dest for next rule
    broadcastrules!(Base.tail(models), dest, source, index, t, args...) 
end

""" 
    broadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractInPlaceModel}
[`AbstractInPlaceModel`](@ref) Broadcasts rules for each cell in the grid, for each module. 
Rules must manually write to the `source` array. return values are ignored.
"""
broadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractInPlaceModel} = begin
    broadcast(rule, models[1], source, index, t, (source,), args...)
    broadcastrules!(Base.tail(models), source, dest, index, t, args...)
end
broadcastrules!(models::Tuple{}, source, dest, index, t, args...) = source, dest


""" 
$(SIGNATURES)
Rules for altering cell values

### Arguments:
- `rule::AbstractModel`: 
- `state`: value of the current cell
- `index`: row, column coordinate tuple for the current cell
- `t`: current time step
- `source`: the whole source array
- `args`: additional arguments passed through from user input to [`sim!`](@ref)

"""
function rule(model::Void, state, index, t, source, args...) end

