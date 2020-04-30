"""
    inbounds(x, max, overflow)

Check grid boundaries for a single coordinate and max value or a tuple
of coorinates and max values.

Returns a tuple containing the coordinate(s) followed by a boolean `true`
if the cell is in bounds, `false` if not.

Overflow of type [`RemoveOverflow`](@ref) returns the coordinate and `false` to skip
coordinates that overflow outside of the grid.
[`WrapOverflow`](@ref) returns a tuple with the current position or it's
wrapped equivalent, and `true` as it is allways in-bounds.
"""
@inline inbounds(xs::Tuple, maxs::Tuple, overflow) = begin
    a, inbounds_a = inbounds(xs[1], maxs[1], overflow)
    b, inbounds_b = inbounds(xs[2], maxs[2], overflow)
    (a, b), inbounds_a & inbounds_b
end
@inline inbounds(x::Number, max::Number, overflow::RemoveOverflow) =
    x, isinbounds(x, max, overflow)
@inline inbounds(x::Number, max::Number, overflow::WrapOverflow) =
    if x < oneunit(x)
        max + rem(x, max), true
    elseif x > max
        rem(x, max), true
    else
        x, true
    end
@inline isinbounds(xs::Tuple, maxs::Tuple, overflow) = all(isinbounds.(xs, maxs, Ref(overflow)))
@inline isinbounds(x::Number, max::Number, overflow::RemoveOverflow) =
    x > zero(x) && x <= max

"""
Check if a cell is masked, using the passed-in mask grid.
"""
@inline ismasked(data::AbstractSimData, I...) = ismasked(mask(data), I...)
@inline ismasked(data::GridData, I...) = ismasked(mask(data), I...)
@inline ismasked(mask::Nothing, I...) = false
@inline ismasked(mask::AbstractArray, I...) = begin
    @inbounds return !(mask[I...])
end

unwrap(::Val{X}) where X = X
unwrap(::Type{Val{X}}) where X = X
