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


"""
    RunAt(rules...)
    RunAt(rules::Tuple)

`RunAt`s allow running a `Rule` or multiple `Rule`s at a lower frequeny
than the main simulation, using a `range` matching the main `tspan` but with a larger
span, or specific events - by using a vector of arbitrary times in `tspan`.
"""
struct RunAt{R,W,Ru<:Tuple,Ti<:AbstractVector} <: RuleWrapper{R,W}
    rules::Ru
    times::Ti
end
RunAt(rules...; times) = RunAt(rules, times)
RunAt(rules::Tuple; times) = RunAt(rules, times)
function RunAt(rules::Tuple, times)
    rkeys = Tuple{union(map(k -> _asiterable(_readkeys(k)), rules)...)...}
    wkeys = Tuple{union(map(k -> _asiterable(_writekeys(k)), rules)...)...}
    RunAt{rkeys,wkeys,typeof(rules),typeof(times)}(rules, times)
end

rules(runat::RunAt) = runat.rules
# Only the first rule in runat can be a NeighborhoodRule, but this seems annoying...
radius(runat::RunAt) = radius(first(rules(runat)))
neighborhoodkey(runat::RunAt) = neighborhoodkey(runat[1])

function sequencerules!(simdata::AbstractSimData, rules::Tuple{<:RunAt,Vararg})
    runat = rules[1]
    if currenttime(simdata) in runat.times
        # Run the sequenced rule
        simdata = sequencerules!(simdata, DynamicGrids.rules(runat))
    end
    # Run the rest of the rules recursively
    sequencerules!(simdata, tail(rules))
end

function Base.tail(runat::RunAt{R,W}) where {R,W}
    runat = tail(rules(runat))
    RunAt{R,W,typeof(runat)}(runat)
end
Base.getindex(runat::RunAt, i) = getindex(rules(runat), i)
Base.iterate(runat::RunAt) = iterate(rules(runat))
Base.length(runat::RunAt) = length(rules(runat))
Base.firstindex(runat::RunAt) = firstindex(rules(runat))
Base.lastindex(runat::RunAt) = lastindex(rules(runat))
