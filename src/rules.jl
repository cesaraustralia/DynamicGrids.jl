abstract type AbstractCellular end

const dayspermonth = 365.2422/12  

@with_kw struct MixedDispersal{N,A,P,F<:Number,R<:UnitRange} <: AbstractCellular
    neighborhood::N = DispersalNeighborhood([1.0, 0.5, 0.25])
    suitability::A = []
    population::P = []
    localprob::F = 0.9
    spotprob::F = 0.9
    spotrange::R = -30:30
end

rule(model::MixedDispersal, state, cc, ind, source, args...) =  begin
    rand() > (8 - cc) / 8 && model.suitability[ind...] > 
        zero(eltype(model.suitability)) ?  one(state) : state
end

rule(model::MixedDispersal, state, cc, ind, source, args...) =  begin
    rand() > (8 - cc) / 8 && model.suitability[ind...] > zero(eltype(model.suitability)) ?  one(state) : state
end

prekernel(model::MixedDispersal, state, ind, source, t, args...) = begin
    # if state > zero(state) && rand() > model.spotprob
    #     h, w = size(source)
    #     row, col = rand(model.spotrange, 2) .+ ind
    #     row = max(min(row, h), one(row))
    #     col = max(min(col, w), one(col))
    #     if model.suitability[row, col] > zero(model.suitability[row, col])
    #         source[row, col] = one(state)
    #     end
    # end
end

@with_kw struct Life{N} <: AbstractCellular
    neighborhood::N = MooreNeighborhood(overflow=Wrap())
    B::Array{Int,1} = [3]
    S::Array{Int,1} = [2,3]
end

rule(model::Life, state, cc, args...) =
    cc in model.B || (state == one(state) && cc in model.S) ? one(state) : zero(state)
