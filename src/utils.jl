
"""
    ismasked(data, I...)

Check if a cell is masked, using the `mask` array.

Used used internally during simulations to skip masked cells.

If `mask` was not passed to the `Output` constructor or `sim!`
it defaults to `nothing` and `false` is always returned.
"""
ismasked(data::AbstractSimData, I...) = ismasked(mask(data), I...)
ismasked(data::GridData, I...) = ismasked(mask(data), I...)
ismasked(mask::Nothing, I...) = false
ismasked(mask::AbstractArray, I...) = @inbounds !(mask[I...])

wrap(x) = Val(x)
wrap(T::Type) = wrap(T.parameters)
wrap(xs::Union{Core.SimpleVector,Tuple,AbstractArray}) = (map(x -> Val(x), xs)...,)

unwrap(x) = x
unwrap(::Val{X}) where X = X
unwrap(::Type{Val{X}}) where X = X

"""
    isinferred(output::Output, ruleset::Ruleset)
    isinferred(output::Output, rules::Rule...)

Test if a custom rule is inferred and the return type is correct when
`applyrule` or `applyrule!` is run.

Type-stability can give orders of magnitude improvements in performance.
"""
isinferred(output::Output, rules::Tuple) = isinferred(output, rules...)
isinferred(output::Output, rules::Rule...) = isinferred(output, Ruleset(rules...))
function isinferred(output::Output, ruleset::Ruleset)
    ext = extent(output)
    ext = @set ext.init = asnamedtuple(init(output))
    simdata = precalcrules(SimData(ext, ruleset), rules(ruleset))
    map(rules(simdata)) do rule
        isinferred(simdata, rule)
    end
    return true
end
isinferred(simdata::SimData, rule::Rule) = _isinferred(simdata, rule)
function isinferred(simdata::SimData, 
    rule::Union{NeighborhoodRule,Chain{<:Any,<:Any,<:Tuple{<:NeighborhoodRule,Vararg}}}
)
    grid = simdata[neighborhoodkey(rule)]
    r = max(1, radius(rule))
    T = eltype(grid)
    S = 2r + 1
    buffer = SArray{Tuple{S,S},T,2,S^2}(Tuple(zero(T) for i in 1:S^2))
    rule = setbuffer(rule, buffer)
    return _isinferred(simdata, rule)
end
function isinferred(simdata::SimData, rule::ManualRule)
    rkeys, rgrids = getreadgrids(rule, simdata)
    wkeys, wgrids = getwritegrids(rule, simdata)
    simdata = @set simdata.grids = combinegrids(rkeys, rgrids, wkeys, wgrids)
    readval = readgrids(rkeys, rgrids, 1, 1)
    @inferred applyrule!(simdata, rule, readval, (1, 1))
    return true
end

function _isinferred(simdata, rule)
    rkeys, rgrids = getreadgrids(rule, simdata)
    wkeys, wgrids = getwritegrids(rule, simdata)
    simdata = @set simdata.grids = combinegrids(rkeys, rgrids, wkeys, wgrids)
    readval = readgrids(rkeys, rgrids, 1, 1)
    ex_writeval = Tuple(example_writeval(wgrids))
    writeval = @inferred applyrule(simdata, rule, readval, (1, 1))
    typeof(Tuple(writeval)) == typeof(ex_writeval) ||
        error("return type `$(typeof(Tuple(writeval)))` doesn't match grids `$(typeof(ex_writeval))`")
    return true
end

example_writeval(grids::Tuple) = map(example_writeval, grids)
example_writeval(grid::WritableGridData) = grid[1, 1]

asnamedtuple(x::NamedTuple) = x
asnamedtuple(x::AbstractArray) = (_default_=x,)
asnamedtuple(e::Extent) = Extent(asnamedtuple(init(e)), mask(e), aux(e), tspan(e))

zerogrids(initgrid::AbstractArray, nframes) = [zero(initgrid) for f in 1:nframes]
zerogrids(initgrids::NamedTuple, nframes) =
    [map(grid -> zero(grid), initgrids) for f in 1:nframes]
