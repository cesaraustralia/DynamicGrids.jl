const RADIUSDOC = """
    `radius` can be a `Neighborhood`, an `Int`, or a tuple of tuples,
    e.g. for 2d it could be: `((1, 2), (2, 1))::Tuple{Tuple{Int,Int},Tuple{Int,Int}}`.
    """

"""
    pad_axes(A, hood::Neighborhood{R})
    pad_axes(A, radius::Int)

Add padding to axes of array `A`, returning a `Tuple` of `UnitRange`.
$RADIUSDOC
"""
function pad_axes(A, rs::Tuple)
    map(axes(A), rs) do axis, r
        firstindex(axis) - r[1]:lastindex(axis) + r[2]
    end
end

"""
    unpad_axes(A, radius)

Remove padding of `radius` from axes of `A`, returning a `Tuple` of `UnitRange`.
$RADIUSDOC
"""
function unpad_axes(A, rs::Tuple)
    map(axes(A), rs) do axis, r
        (first(axis) + r[1]):(last(axis) - r[2])
    end
end

"""
    pad_array(A, radius; [padval])

Add padding of `radius` to array `A`, redurning a new array.

$RADIUSDOC

`padval` defaults to `zero(eltype(A))`.
"""
function pad_array(A, radius; padval=zero(eltype(A)))
    _pad_array(A, radius, padval)
end

# Handle either specific pad radius for each edge or single Int radius
function _pad_array(A::AbstractArray, r::Int, padval)
    _pad_array(A, _radii(A, r), padval)
end
function _pad_array(A::AbstractArray{T}, rs::Tuple, padval) where T
    paddedaxes = pad_axes(A, rs)
    T1 = promote_type(T, typeof(padval))
    paddedparent = similar(A, T1, length.(paddedaxes)...)
    paddedparent .= Ref(padval)
    padded = OffsetArray(paddedparent, paddedaxes)
    unpad_view(paddedparent, rs) .= A
    return padded
end

"""
    unpad_array(A, radius)

Remove padding of `radius` from array `A`, returning a new array.

$RADIUSDOC
"""
function unpad_array(A::OffsetArray, rs::Tuple) 
    _checkpad(A, rs)
    return unpad_array(parent(A), rs)
end
unpad_array(A::AbstractArray, rs::Tuple) = A[unpad_axes(A, rs)...]

"""
    unpad_view(A, radius)

Remove padding of `radius` from array `A`, returning a view of `A`.

$RADIUSDOC
"""
function unpad_view(A::OffsetArray, rs::Tuple) 
    _checkpad(A, rs)
    return unpad_view(parent(A), rs)
end
unpad_view(A::AbstractArray, rs::Tuple) = view(A, unpad_axes(A, rs)...)

# Handle a Neighborhood or Int for radius in all (un)pad methods
for f in (:pad_axes, :unpad_axes, :pad_array, :unpad_array, :unpad_view)
    @eval begin
        $f(A, hood::Neighborhood{R}; kw...) where R = $f(A, R; kw...)
        $f(A, radius::Int; kw...) = $f(A, _radii(A, radius); kw...)
    end
end

function _checkpad(A, rs)
    o_pad = map(a -> -(first(a) - 1), axes(A)) 
    r_pad = map(first, rs)
    o_pad == r_pad || throw(ArgumentError("OffsetArray padding $opad does not match radii padding $r_pad"))
    return nothing
end

_radii(A::AbstractArray{<:Any,N}, r) where N = ntuple(_ -> (r, r), N)
