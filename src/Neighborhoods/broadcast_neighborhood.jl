"""
    broadcast_neighborhood(f, hood::Neighborhood, As...)

Simple neighborhood application, where `f` is passed 
each neighborhood in `A`, returning a new array.

The result is smaller than `A` on all sides, by the neighborhood radius.
"""
function broadcast_neighborhood(f, hood::Neighborhood, s1, s2, s_tail...) 
    sources = (s1, s2, s_tail...)
    _checksizes(sources)
    sourceview = unpad_view(s1, hood)
    broadcast(sourceview, CartesianIndices(sourceview)) do  I
        applyneighborhood(f, hood, sources, I)
    end
end
function broadcast_neighborhood(f, hood::Neighborhood, source::AbstractArray)
    sourceview = unpad_view(source, hood)
    broadcast(sourceview, CartesianIndices(sourceview)) do _, I
        applyneighborhood(f, hood, source, I)
    end
end

"""
    broadcast_neighborhood!(f, hood::Neighborhood{R}, dest, sources...)

Simple neighborhood broadcast where `f` is passed each neighborhood
of `src` (except padding), writing the result of `f` to `dest`.

`dest` must either be smaller than `src` by the neighborhood radius on all
sides, or be the same size, in which case it is assumed to also be padded.
"""
function broadcast_neighborhood!(f, hood::Neighborhood, dest, sources...)
    _checksizes(sources)
    if axes(dest) === axes(first(src))
        destview = unpad_view(dest, hood)
        broadcast!(destview, CartesianIndices(destview)) do I
            applyneighborhood(f, hood, sources, I)
        end
    else
        broadcast!(dest, CartesianIndices(dest)) do I
            applyneighborhood(f, hood, sources, I)
        end
    end
end

function _checksizes(sources::Tuple)
    map(sources) do s
        size(s) === size(first(sources)) || throw(ArgumentError("Source array sizes must match"))
    end
    return nothing
end

function applyneighborhood(f, hood, sources::Tuple, I)
    hoods = map(s -> unsafe_updatewindow(hood, s, I), sources)
    vals = map(s -> s[I], sources)
    f(hoods, vals)
end
function applyneighborhood(f, hood, source::AbstractArray, I)
    f(unsafe_updatewindow(hood, source, I), source[I])
end
