
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
isinferred(output::Output, rules::Rule...) = isinferred(output, rules)
isinferred(output::Output, rules::Tuple) = isinferred(output, Ruleset(rules...))
function isinferred(output::Output, ruleset::Ruleset)
    simdata = _updaterules(rules(ruleset), SimData(output, ruleset))
    map(rules(simdata)) do rule
        isinferred(simdata, rule)
    end
    return true
end
isinferred(simdata::AbstractSimData, rule::Rule) = _isinferred(simdata, rule)
function isinferred(simdata::AbstractSimData, 
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
function isinferred(simdata::AbstractSimData, rule::SetCellRule)
    rkeys, rgrids = _getreadgrids(rule, simdata)
    wkeys, wgrids = _getwritegrids(rule, simdata)
    simdata = @set simdata.grids = _combinegrids(rkeys, rgrids, wkeys, wgrids)
    readval = _readcell(simdata, rkeys, 1, 1)
    @inferred applyrule!(simdata, rule, readval, (1, 1))
    return true
end

function _isinferred(simdata, rule)
    rkeys, rgrids = _getreadgrids(rule, simdata)
    wkeys, wgrids = _getwritegrids(rule, simdata)
    simdata = @set simdata.grids = _combinegrids(rkeys, rgrids, wkeys, wgrids)
    readval = _readcell(simdata, rkeys, 1, 1)
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
@inline _astuple(keys::Tuple, state) = state
@inline _astuple(key, state) = (state,)

@inline _asnamedtuple(x::NamedTuple) = x
@inline _asnamedtuple(x::AbstractArray) = (_default_=x,)
@inline function _asnamedtuple(e::Extent) 
    @set! e.init = _asnamedtuple(init(e))
    @set e.padval = _samenamedtuple(init(e), padval(e))
end

@inline _samenamedtuple(init::NamedTuple{K}, padval::NamedTuple{K}) where K = x
@noinline _samenamedtuple(init::NamedTuple{K}, padval::NamedTuple{J}) where {K,J} = 
    error("Keys $K and $J do not match")
@inline _samenamedtuple(init::NamedTuple{K}, x::Tuple) where K = NamedTuple{K}(x)
@inline _samenamedtuple(init::NamedTuple, x) = map(_ -> x, init) 


_unwrap(x) = x
_unwrap(::Val{X}) where X = X
_unwrap(::Type{<:Val{X}}) where X = X


# Convert regular index to block index
@inline function _indtoblock(x::Int, blocksize::Int)
    (x - 1) ÷ blocksize + 1
end

# Convert block index to regular index
@inline _blocktoind(x, blocksize) = (x - 1) * blocksize + 1
