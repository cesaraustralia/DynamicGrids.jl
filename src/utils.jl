
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
    x = @inferred applyrule(simdata, rule, init[1, 1], (1, 1))
    typeof(x) == eltype(init) ||
        error("Returned type `$(typeof(x))` doesn't match grid eltype `$(eltype(init))`")
    true
end
isinferred(simdata::SimData, rule::ManualRule, init::AbstractArray) = begin
    simdata = @set simdata.grids = map(WritableGridData, simdata.grids)
    @inferred applyrule!(simdata, rule, init[1, 1], (1, 1))
    true
end

asnamedtuple(x::NamedTuple) = x
asnamedtuple(x::AbstractArray) = (_default_=x,)
asnamedtuple(e::Extent) = Extent(asnamedtuple(init(e)), mask(e), aux(e), tspan(e))

zerogrids(initgrid::AbstractArray, nframes) = [zero(initgrid) for f in 1:nframes]
zerogrids(initgrids::NamedTuple, nframes) =
    [map(grid -> zero(grid), initgrids) for f in 1:nframes]
