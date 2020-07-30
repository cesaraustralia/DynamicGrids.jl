
"""
Check if a cell is masked, using the passed-in mask grid.
"""
ismasked(data::AbstractSimData, I...) = ismasked(mask(data), I...)
ismasked(data::GridData, I...) = ismasked(mask(data), I...)
ismasked(mask::Nothing, I...) = false
ismasked(mask::AbstractArray, I...) = begin
    @inbounds return !(mask[I...])
end

wrap(x) = Val(x)
wrap(T::Type) = wrap(T.parameters)
wrap(xs::Union{Core.SimpleVector,Tuple,AbstractArray}) = (map(x -> Val(x), xs)...,)

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
        isinferred(simdata, rule)
    end
    true
end
isinferred(simdata::SimData, rule::Rule) = _isinferred(simdata, rule)
isinferred(simdata::SimData, rule::Union{NeighborhoodRule,Chain{<:Any,<:Any,<:Tuple{<:NeighborhoodRule,Vararg}}}) = begin
    griddata = simdata[neighborhoodkey(rule)]
    buffers, bufrules = spreadbuffers(rule, DynamicGrids.init(griddata))
    rule = bufrules[1]
    _isinferred(simdata, rule)
end
isinferred(simdata::SimData, rule::ManualRule) = begin
    rkeys, rgrids = getgrids(_Read_(), rule, simdata)
    wkeys, wgrids = getgrids(_Write_(), rule, simdata)
    simdata = @set simdata.grids = combinegrids(rkeys, rgrids, wkeys, wgrids)
    readval = readgrids(rkeys, rgrids, 1, 1)
    @inferred applyrule!(simdata, rule, readval, (1, 1))
    true
end

function _isinferred(simdata, rule)
    rkeys, rgrids = getgrids(_Read_(), rule, simdata)
    wkeys, wgrids = getgrids(_Write_(), rule, simdata)
    simdata = @set simdata.grids = combinegrids(rkeys, rgrids, wkeys, wgrids)
    readval = readgrids(rkeys, rgrids, 1, 1)
    ex_writeval = Tuple(example_writeval(wgrids))
    writeval = @inferred applyrule(simdata, rule, readval, (1, 1))
    typeof(Tuple(writeval)) == typeof(ex_writeval) ||
        error("return type `$(typeof(Tuple(writeval)))` doesn't match grids `$(typeof(ex_writeval))`")
    true
end

example_writeval(grids::Tuple) = map(example_writeval, grids)
example_writeval(grid::WritableGridData) = grid[1, 1]

asnamedtuple(x::NamedTuple) = x
asnamedtuple(x::AbstractArray) = (_default_=x,)
asnamedtuple(e::Extent) = Extent(asnamedtuple(init(e)), mask(e), aux(e), tspan(e))

zerogrids(initgrid::AbstractArray, nframes) = [zero(initgrid) for f in 1:nframes]
zerogrids(initgrids::NamedTuple, nframes) =
    [map(grid -> zero(grid), initgrids) for f in 1:nframes]
