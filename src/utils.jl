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


broadcastable_indices(a) = broadcastable_indices(Int, a)
broadcastable_indices(T::Type, a) = begin
    h, w = size(a)
    typeof(similar(a, Tuple{T,T}))(collect((row, col) for row in 1:h, col in 1:w))
end


"""
    sizefromradius(radius)

Get the size of a neighborhood dimension from its radius, 
which is always 2r + 1.
"""
hoodsize(radius::Integer) = 2radius + 1

"""
Return a tuple of the base types of the rules in the ruleset
"""
ruletypes(ruleset::Ruleset) = ruletypes(typeof(Ruleset.rules))
ruletypes(t::Type) = t.name.wrapper
ruletypes(ts::Type{<:Tuple}) = (ruletypes.(ts.parameters)...,)

@inline ismasked(data::AbstractSimData, i...) = ismasked(mask(data), i...)
@inline ismasked(mask::Nothing, i...) = false
@inline ismasked(mask::AbstractArray, i...) = @inbounds return !mask[i...]
