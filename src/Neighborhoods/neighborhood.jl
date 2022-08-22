"""
    Neighborhood

Neighborhoods define the pattern of surrounding cells in the "neighborhood"
of the current cell. The `neighbors` function returns the surrounding
cells as an iterable.

The main kinds of neighborhood are demonstrated below:

![Neighborhoods](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/Neighborhoods.png)

Neighborhoods can be used in `NeighborhoodRule` and `SetNeighborhoodRule` -
the same shapes with different purposes. In a `NeighborhoodRule` the neighborhood specifies
which cells around the current cell are returned as an iterable from the `neighbors` function.
These can be counted, summed, compared, or multiplied with a kernel in an
`AbstractKernelNeighborhood`, using [`kernelproduct`](@ref).

In `SetNeighborhoodRule` neighborhoods give the locations of cells around the central cell,
as [`offsets`] and absolute [`positions`](@ref) around the index of each neighbor. These
can then be written to manually.
"""
abstract type Neighborhood{R,N,L} end

ConstructionBase.constructorof(::Type{<:T}) where T <: Neighborhood{R,N,L} where {R,N,L} =
    T.name.wrapper{R,N,L}

"""
    kernelproduct(rule::NeighborhoodRule})
    kernelproduct(hood::AbstractKernelNeighborhood)
    kernelproduct(hood::Neighborhood, kernel)

Returns the vector dot product of the neighborhood and the kernel,
although differing from `dot` in that the dot product is not take for
vector members of the neighborhood - they are treated as scalars.
"""
function kernelproduct end

"""
    radius(rule, [key]) -> Int

Return the radius of a rule or ruleset if it has one, otherwise zero.
"""
function radius end
radius(hood::Neighborhood{R}) where R = R

"""
    neighbors(x::Union{Neighborhood,NeighborhoodRule}}) -> iterable

Returns an indexable iterator for all cells in the neighborhood,
either a `Tuple` of values or a range.

Custom `Neighborhood`s must define this method.
"""
function neighbors end
neighbors(hood::Neighborhood) = begin
    w = _window(hood)
    map(i -> w[i], window_indices(hood))
end

"""
    offsets(x) -> iterable

Returns an indexable iterable over all cells, containing `Tuple`s of
the index offset from the central cell.

Custom `Neighborhood`s must define this method.
"""
function offsets end
offsets(hood::Neighborhood) = offsets(typeof(hood))
_window(hood::Neighborhood) = hood._window

"""
    positions(x::Union{Neighborhood,NeighborhoodRule}}, cellindex::Tuple) -> iterable

Returns an indexable iterable, over all cells as `Tuple`s of each
index in the main array. Useful in `SetNeighborhoodRule` for
setting neighborhood values, or for getting values in an Aux array.
"""
function positions end
@inline positions(hood::Neighborhood, I::CartesianIndex) = positions(hood, Tuple(I))
@inline positions(hood::Neighborhood, I::Int...) = positions(hood, I)
@inline positions(hood::Neighborhood, I::Tuple) = map(o -> o .+ I, offsets(hood))

"""
    distances(hood::Neighborhood)

Get the center-to-center distance of each neighborhood position from the central cell,
so that horizontally or vertically adjacent cells have a distance of `1.0`, and a
diagonally adjacent cell has a distance of `sqrt(2.0)`.

Vales are calculated at compile time, so `distances` can be used inside rules with little
overhead.
"""
@generated function distances(hood::Neighborhood{R,N,L}) where {R,N,L}
    expr = Expr(:tuple, ntuple(i -> :(bd[bi[$i]]), L)...)
    return quote
        bd = window_distances(hood)
        bi = window_indices(hood)
        $expr
    end
end

@generated function window_indices(H::Neighborhood{R,N}) where {R,N}
    # Offsets can be anywhere in the window, specified with
    # all dimensions. Here we transform them to a linear index.
    bi = map(offsets(H)) do o
        # Calculate strides
        S = 2R + 1
        strides = ntuple(i -> S^(i-1), N)
        # Offset indices are centered, we want them as regular array indices
        # Return the linear index in the square window
        sum(map((i, s) -> (i + R) * s, o, strides)) + 1
    end
    return Expr(:tuple, bi...)
end

@generated function window_distances(hood::Neighborhood{R,N}) where {R,N}
    values = map(CartesianIndices(ntuple(_ -> SOneTo{2R+1}(), N))) do I
        sqrt(sum((Tuple(I) .- (R + 1)) .^ 2))
    end
    x = SArray(values)
    quote
        return $x
    end
end

cartesian_offsets(hood::Neighborhood{R,N,L}) where {R,N,L} = map(CartesianIndex, offsets(hood))

Base.eltype(hood::Neighborhood) = eltype(_window(hood))
Base.length(hood::Neighborhood{<:Any,<:Any,L}) where L = L
Base.ndims(hood::Neighborhood{<:Any,N}) where N = N
# Note: size is radial, and may not relate to `length` in the same way
# as in an array. A neighborhood does not have to include all cells includeding
# in the area covered by `size` and `axes`.
Base.size(hood::Neighborhood{R,N}) where {R,N} = ntuple(_ -> 2R+1, N)
Base.axes(hood::Neighborhood{R,N}) where {R,N} = ntuple(_ -> SOneTo{2R+1}(), N)
Base.iterate(hood::Neighborhood) = hood[1], 2
Base.iterate(hood::Neighborhood, i::Int) = i > length(hood) ? nothing : (hood[i], i + 1)
Base.getindex(hood::Neighborhood, i) = begin
    getindex(_window(hood), window_indices(hood)[i])
end

# Utils

# Get the size of a neighborhood dimension from its radius,
# which is always 2r + 1.
@inline hoodsize(hood::Neighborhood{R}) where R = hoodsize(R)
@inline hoodsize(radius::Integer) = 2radius + 1

# Copied from StaticArrays. If they can do it...
Base.@pure function tuple_contents(::Type{X}) where {X<:Tuple}
    return tuple(X.parameters...)
end
tuple_contents(xs::Tuple) = xs

"""
    unsafe_readwindow(hood::Neighborhood, A::AbstractArray, I) => SArray

Get a single window square from an array, as an `SArray`, checking bounds.
"""
readwindow(hood::Neighborhood, A::AbstractArray, I::Int...) = readwindow(hood, A, I)
@inline function readwindow(hood::Neighborhood{R,N}, A::AbstractArray, I) where {R,N}
    for O in ntuple(_ -> (-R, R), N)
        edges = Tuple(I) .+ O
        map(I -> checkbounds(A, I...), edges)
    end
    return unsafe_readwindow(hood, A, I...)
end

"""
    unsafe_readwindow(hood::Neighborhood, A::AbstractArray, I) => SArray

Get a single window square from an array, as an `SArray`, without checking bounds.
"""
@inline unsafe_readwindow(hood::Neighborhood, A::AbstractArray, I::CartesianIndex) =
    unsafe_readwindow(hood, A, Tuple(I))
@inline unsafe_readwindow(hood::Neighborhood, A::AbstractArray, I::Int...) =
    unsafe_readwindow(hood, A, I)
@generated function unsafe_readwindow(
    ::Neighborhood{R,N}, A::AbstractArray{T,N}, I::NTuple{N,Int}
) where {T,R,N}
    S = 2R+1
    L = S^N
    sze = ntuple(_ -> S, N)
    vals = Expr(:tuple)
    nh = CartesianIndices(ntuple(_ -> -R:R, N))
    for i in 1:L
        Iargs = map(Tuple(nh[i]), 1:N) do nhi, n
            :(I[$n] + $nhi)
        end
        Iexp = Expr(:tuple, Iargs...)
        exp = :(@inbounds A[$Iexp...])
        push!(vals.args, exp)
    end

    sze_exp = Expr(:curly, :Tuple, sze...)
    return :(SArray{$sze_exp,$T,$N,$L}($vals))
end
@generated function unsafe_readwindow(
    ::Neighborhood{R,N1}, A::AbstractArray{T,N2}, I::NTuple{N3,Int}
) where {T,R,N1,N2,N3}
    throw(DimensionMismatch("neighborhood has $N1 dimensions while array has $N2 and index has $N3"))
end

# Reading windows without padding
# struct Padded{S,V}
#     padval::V
# end
# Padded{S}(padval::V) where {S,V} = Padded{S,V}(padval)

# @generated function unsafe_readwindow(
#     ::Neighborhood{R,N}, bounds::Padded{V}, ::AbstractArray{T,N}, I::NTuple{N,Int}
# ) where {T,R,N,V}
#     R = 1
#     S = 2R+1
#     L = S^N
#     sze = ntuple(_ -> S, N)
#     vals = Expr(:tuple)
#     for X in CartesianIndices(ntuple(_ -> -R:R, N))
#         if X in CartesianIndices(V)
#             # Generate indices for this position
#             Iargs = map(Tuple(X), 1:N) do x, n
#                 :(I[$n] + $x)
#             end
#             Iexp = Expr(:tuple, Iargs...)
#             push!(vals.args, :(@inbounds A[$Iexp...]))
#         else
#             push!(vals.args, :(bounds.padval))
#         end
#     end

#     sze_exp = Expr(:curly, :Tuple, sze...)
#     return :(SArray{$sze_exp,$T,$N,$L}($vals))
# end

"""
    updatewindow(x, A::AbstractArray, I...) => Neighborhood

Set the window of a neighborhood to values from the array A around index `I`.

Bounds checks will reduce performance, aim to use `unsafe_setwindow` directly.
"""
@inline function updatewindow(x, A::AbstractArray, i, I...)
    setwindow(x, readwindow(x, A, i, I...))
end

"""
    unsafe_setwindow(x, A::AbstractArray, I...) => Neighborhood

Set the window of a neighborhood to values from the array A around index `I`.

No bounds checks occur, ensure that A has padding of at least the neighborhood radius.
"""
@inline function unsafe_updatewindow(h::Neighborhood, A::AbstractArray, i, I...)
    setwindow(h, unsafe_readwindow(h, A, i, I...))
end
