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
    done = false
    dest = similar(source)
    for t in time
        update_output(output, source, t, pause)
        !done || break
        source, dest = automate!(dest, source, model, t, args...) 
    end
end

""" 
Runs the model once for the whole grid.
does not interact with neighborhoods, layers etc, just runs other methods.
"""

automate!(dest, source, models::Tuple, t, args...) = begin
    width, height = size(source)
    index = collect((col,row) for col in 1:width, row in 1:height)
    # Run the kernel for every cell, the result sets the dest cell
    applyrules!(models, source, dest, index, t, args...)
end 
automate!(dest, source, model, args...) = automate!(dest, source, (model,), args...)

" Type-stable recursive application of model rule "
function applyrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractCellular}
    # Write output to dest array
    broadcast!(rule, dest, models[1], source, index, t, (source,), (dest,), args...)
    # Swap source and dest
    applyrules!(Base.tail(models), dest, source, index, t, args...) 
end
function applyrules!(models::Tuple{T,Vararg}, source, dest, index, t, args...) where {T<:AbstractInPlaceCellular}
    broadcast(rule, models[1], source, index, t, (source,), (dest,), args...)
    applyrules!(Base.tail(models), source, dest, index, t, args...)
end
applyrules!(models::Tuple{}, source, dest, index, t, args...) = source, dest

" Rules for altering cell values "
function rule() end

" Default is to do nothing "
rule(model, args...) = nothing
