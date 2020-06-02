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

@inline isinbounds(x, max, overflow::WrapOverflow) = true
@inline isinbounds(xs::Tuple, maxs::Tuple, overflow::RemoveOverflow) = 
    all(isinbounds.(xs, maxs, Ref(overflow)))
@inline isinbounds(x::Number, max::Number, overflow::RemoveOverflow) =
    x > zero(x) && x <= max

"""
Check if a cell is masked, using the passed-in mask grid.
"""
ismasked(data::AbstractSimData, I...) = ismasked(mask(data), I...)
ismasked(data::GridData, I...) = ismasked(mask(data), I...)
ismasked(mask::Nothing, I...) = false
ismasked(mask::AbstractArray, I...) = begin
    @inbounds return !(mask[I...])
end

unwrap(x) = x
unwrap(::Val{X}) where X = X
unwrap(::Type{Val{X}}) where X = X

"""
    isinferred(output::Output, ruleset::Ruleset)

Test if a custom rule return type is inferred and correct.
Type-stability can give orders of magnitude improvements in performance.

If there is no `init` array or `NamedTuple` in the ruleset
it must be passed in as a keyword argument.

Passing `starttime` is optional, in case the time type has some effect on the rule.
"""
isinferred(output::Output, rules::Rule...) = 
    isinferred(output, Ruleset(rules...))
isinferred(output::Output, ruleset::Ruleset) = begin
    ext = extent(output)
    ext = @set ext.init = asnamedtuple(init(output))
    simdata = SimData(ext, ruleset)
    map(rules(ruleset)) do rule
        isinferred(simdata, rule, init(output))
    end
    true
end
isinferred(simdata::SimData, rule::Rule, init::AbstractArray) = begin
    x = @inferred applyrule(rule, simdata, init[1, 1], (1, 1))
    typeof(x) == eltype(init) ||
        error("Returned type `$(typeof(x))` doesn't match grid eltype `$(eltype(init))`")
    true
end
isinferred(simdata::SimData, rule::ManualRule, init::AbstractArray) = begin
    simdata = @set simdata.grids = map(WritableGridData, simdata.grids)
    @inferred applyrule!(rule, simdata, init[1, 1], (1, 1))
    true
end

"""
    allocbuffers(init::AbstractArray, hood::Neighborhood)
    allocbuffers(init::AbstractArray, radius::Int)

Allocate buffers for the Neighborhood. The `init` array should 
be of the same type as the grid the neighborhood runs on.
"""
allocbuffers(init::AbstractArray, hood::Neighborhood) = allocbuffers(init, radius(hood))
allocbuffers(init::AbstractArray, r::Int) = Tuple(allocbuffer(init, r) for i in 1:2r)

allocbuffer(init::AbstractArray, hood::Neighborhood) = allocbuffer(init, radius(hood))
allocbuffer(init::AbstractArray, r::Int) = zeros(eltype(init), 2r+1, 2r+1)

asnamedtuple(x::NamedTuple) = x
asnamedtuple(x::AbstractArray) = (_default_=x,)
asnamedtuple(e::Extent) = Extent(asnamedtuple(init(e)), mask(e), tspan(e), aux(e))
