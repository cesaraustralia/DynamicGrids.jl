"""
    RunIf(f, rule)

`RunIf`s allows wrapping a rule in a condition, passed the `SimData` object and the cell state and index.

```julia
RunIf(dispersal) do data, state, I
    state >= oneunit(state)
end
`` `
"""
struct RunIf{R,W,F,T<:Rule{R,W}} <: RuleWrapper{R,W}
    f::F
    rule::T
end

rule(runif::RunIf) = runif.rule
radius(runif::RunIf) = radius(rule(runif))
neighborhoodkey(runif::RunIf) = neighborhoodkey(rule(runif))

@inline function _setbuffer(runif::RunIf{R,W}, buf) where {R,W}
    r = _setbuffer(rule(runif), buf)
    RunIf{R,W,typeof(r)}(r)
end

# We have to hook into cell_kernel! to handle the option of no return value
@inline function cell_kernel!(
    wgrids, simdata, ::Type{<:Rule}, condition::RunIf, rkeys, rgrids, wkeys, I...
)
    readval = _readgrids(rkeys, rgrids, I...)
    if condition.f(data, readval, I)
        writeval = applyrule(simdata, rule(condition), readval, I)
        _writegrids!(wgrids, writeval, I...)
    else
        # Otherwise copy source to dest without change
        _writegrids!(wgrids, _readgrids(wkeys, wgrids, I...), I...)
    end
    return nothing
end
# We have to hook into cell_kernel! to handle the option of no return value
@inline function cell_kernel!(
    wgrids, simdata, ::Type{<:SetRule}, condition::RunIf, rkeys, rgrids, wkeys, I...
)
    readval = _readgrids(rkeys, rgrids, I...)
    if condition.f(data, readval, I)
        applyrule!(simdata, rule(condition), readval, I)
    end
    return nothing
end
