
"""
    Base.get(data::SimData, keyorval, I...)

Allows parameters to be taken from a single value, another grid or an aux array.

If aux arrays are a `DimArray` time sequence (with a `Ti` dim) the currect date will be 
calculated automatically.

Currently this is cycled by default, but will use Cyclic mode in DiensionalData.jl in future.
"""
@inline Base.get(data::SimData, val, I...) = val
@inline Base.get(data::SimData, key::Grid{K}, I...) where K = data[K][I...]
@inline Base.get(data::SimData, key::Aux, I...) = _auxval(data, key, I...)

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
    ext = @set ext.init = _asnamedtuple(init(output))
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
    rule = _setbuffer(rule, buffer)
    return _isinferred(simdata, rule)
end
function isinferred(simdata::SimData, rule::ManualRule)
    rkeys, rgrids = _getreadgrids(rule, simdata)
    wkeys, wgrids = _getwritegrids(rule, simdata)
    simdata = @set simdata.grids = _combinegrids(rkeys, rgrids, wkeys, wgrids)
    readval = _readgrids(rkeys, rgrids, 1, 1)
    @inferred applyrule!(simdata, rule, readval, (1, 1))
    return true
end

function _isinferred(simdata, rule)
    rkeys, rgrids = _getreadgrids(rule, simdata)
    wkeys, wgrids = _getwritegrids(rule, simdata)
    simdata = @set simdata.grids = _combinegrids(rkeys, rgrids, wkeys, wgrids)
    readval = _readgrids(rkeys, rgrids, 1, 1)
    ex_writeval = Tuple(_example_writeval(wgrids))
    writeval = @inferred applyrule(simdata, rule, readval, (1, 1))
    typeof(Tuple(writeval)) == typeof(ex_writeval) ||
        error("return type `$(typeof(Tuple(writeval)))` doesn't match grids `$(typeof(ex_writeval))`")
    return true
end


_example_writeval(grids::Tuple) = map(_example_writeval, grids)
_example_writeval(grid::WritableGridData) = grid[1, 1]

_zerogrids(initgrid::AbstractArray, nframes) = [zero(initgrid) for f in 1:nframes]
_zerogrids(initgrids::NamedTuple, nframes) =
    [map(grid -> zero(grid), initgrids) for f in 1:nframes]

@inline _asiterable(x::Symbol) = (x,)
@inline _asiterable(x::Type{<:Tuple}) = x.parameters
@inline _asiterable(x::Tuple) = x

@inline _astuple(rule::Rule, state) = _astuple(_readkeys(rule), state)
@inline _astuple(::Tuple, state) = state
@inline _astuple(::Symbol, state) = (state,)

@inline _asnamedtuple(x::NamedTuple) = x
@inline _asnamedtuple(x::AbstractArray) = (_default_=x,)
@inline _asnamedtuple(e::Extent) = Extent(_asnamedtuple(init(e)), mask(e), aux(e), tspan(e))

@inline _keys2vals(keys::Tuple) = map(Val, keys)
@inline _keys2vals(key::Symbol) = Val(key)


_unwrap(x) = x
_unwrap(::Val{X}) where X = X
_unwrap(::Aux{X}) where X = X
_unwrap(::Type{<:Aux{X}}) where X = X
_unwrap(::Type{<:Val{X}}) where X = X
