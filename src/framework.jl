abstract type AbstractCellular end
abstract type AbstractInPlaceCellular end

abstract type AbstractOverflow end
" Wrap cords that overflow to the opposite side "
struct Wrap <: AbstractOverflow end
" Skip coords that overflow boundaries "
struct Skip <: AbstractOverflow end


""" 
Runs the whole simulation, passing the destination aray to 
the passed in output for each time-step.
"""
sim!(source, model, output, args...; time=1:10000, pause=0.0) = begin
    dest = similar(source)
    for t in time
        update_output(output, source, t, pause) || break
        source, dest = automate!(model, source, dest, t, args...) 
    end
end

""" 
Runs the model once for the whole grid.
does not interact with neighborhoods, layers etc, just runs other methods.
"""

automate!(models::Tuple, source, dest, t, args...) = begin
    width, height = size(source)
    index = collect((col,row) for col in 1:width, row in 1:height)
    # Run the kernel for every cell, the result sets the dest cell
    broadcastrules!(models, source, dest, index, t, args...)
end 
automate!(model, dest, source, args...) = automate!((model,), dest, source, args...)


" Type-stable recursive application of model rule "
broadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractCellular} = begin
    # Write output to dest array
    broadcast!(rule, dest, models[1], source, index, t, (source,), (dest,), args...)
    # Swap source and dest
    broadcastrules!(Base.tail(models), dest, source, index, t, args...) 
end
broadcastrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractInPlaceCellular} = begin
    broadcast(rule, models[1], source, index, t, (source,), (dest,), args...)
    broadcastrules!(Base.tail(models), source, dest, index, t, args...)
end
broadcastrules!(models::Tuple{}, source, dest, index, t, args...) = source, dest


" Rules for altering cell values "
function rule() end

