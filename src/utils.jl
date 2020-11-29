
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

unwrap(x) = x
unwrap(::Val{X}) where X = X
unwrap(::Aux{X}) where X = X
unwrap(::Type{Aux{X}}) where X = X
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

asnamedtuple(x::NamedTuple) = x
asnamedtuple(x::AbstractArray) = (_default_=x,)
asnamedtuple(e::Extent) = Extent(asnamedtuple(init(e)), mask(e), aux(e), tspan(e))

zerogrids(initgrid::AbstractArray, nframes) = [zero(initgrid) for f in 1:nframes]
zerogrids(initgrids::NamedTuple, nframes) =
    [map(grid -> zero(grid), initgrids) for f in 1:nframes]


"""
    auxval(rule::Rule, data::SimData, key, I...)

Returns the value of a single layer or interplated value from a sequence of layers.

Corresponding layers must be include as the `aux` keyword to the `Output` or `sim!`.

If the key is not a symbol 
"""
auxval(data::SimData, val, I...) = val
auxval(data::SimData, key::Union{Symbol,Aux}, I...) = _auxval(aux(data, key), data, key, I...) 
# If there is no time dimension we return the same data for every timestep
_auxval(A::Matrix, data, key, y, x) = A[y, x] 
function _auxval(A::AbstractDimArray{<:Any,2}, data, key, y, x) 
    # X = DD.basetypeof(dims(A, XDim))
    # Y = DD.basetypeof(dims(A, YDim))
    A[y, x]
end
function _auxval(A::AbstractDimArray{<:Any,3}, data, key, y, x) 
    # X = DD.basetypeof(dims(A, XDim))
    # Y = DD.basetypeof(dims(A, YDim))
    A[y, x, auxframe(data, key)]
end

function boundscheck_aux(data::SimData, auxkey::Aux{Key}) where Key 
    a = aux(data)
    (a isa NamedTuple && haskey(a, Key)) || _auxmissingerror(Key)
    gsize = gridsize(data)
    asize = size(a[Key], 1), size(a[Key], 2)
    if asize != gsize
        _auxsizeerror(Key, asize, gsize)
    end
end

@noinline _auxmissingerror(key, asize, gsize) = 
    error("Aux grid $key is not present in aux")
@noinline _auxsizeerror(key, asize, gsize) = 
    error("Aux grid $key is size $asize does not match grid size $gsize")
