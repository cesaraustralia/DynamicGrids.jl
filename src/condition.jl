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
# Forward ruletype, radius and neighborhoodkey to the contained rule
ruletype(runif::RunIf) = ruletype(rule(runif))
radius(runif::RunIf) = radius(rule(runif))
neighborhoodkey(runif::RunIf) = neighborhoodkey(rule(runif))
neighborhood(runif::RunIf) = neighborhood(rule(runif))
neighbors(runif::RunIf) = neighbors(rule(runif))

@inline function setwindow(runif::RunIf{R,W}, win) where {R,W}
    f = runif.f
    r = setwindow(rule(runif), win)
    RunIf{R,W,typeof(f),typeof(r)}(f, r)
end

# We have to hook into cell_kernel! to handle the option of no return value
@inline function cell_kernel!(
    simdata, ruletype::Val{<:Rule}, condition::RunIf, rkeys, wkeys, I...
)
    readval = _readcell(simdata, rkeys, I...)
    if condition.f(simdata, readval, I)
        writeval = applyrule(simdata, rule(condition), readval, I)
        _writecell!(simdata, ruletype, wkeys, writeval, I...)
    else
        # Otherwise copy source to dest without change
        _writecell!(simdata, ruletype, wkeys, _readcell(simdata, wkeys, I...), I...)
    end
    return nothing
end
# We have to hook into cell_kernel! to handle the option of no return value
@inline function cell_kernel!(
    simdata, ::Type{<:SetRule}, condition::RunIf, rkeys, wkeys, I...
)
    readval = _readcell(simdata, rkeys, I...)
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
# Forward ruletype to the contained rule
ruletype(runat::RunAt) = ruletype(first(rules(runat)))
neighborhoodkey(runat::RunAt) = neighborhoodkey(first(rules(runat)))
neighborhood(runat::RunAt) = neighborhood(neighborhood(rules(runat)))
neighbors(runat::RunAt) = neighbors(rules(runat))

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
    rulestail = tail(rules(runat))
    RunAt{R,W,typeof(rulestail),typeof(runat.times)}(rulestail, runat.times)
end
Base.getindex(runat::RunAt, i) = getindex(rules(runat), i)
Base.iterate(runat::RunAt) = iterate(rules(runat))
Base.iterate(runat::RunAt, nothing) = iterate(rules(runat), nothing)
Base.length(runat::RunAt) = length(rules(runat))
Base.firstindex(runat::RunAt) = firstindex(rules(runat))
Base.lastindex(runat::RunAt) = lastindex(rules(runat))
