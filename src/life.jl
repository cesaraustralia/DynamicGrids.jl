abstract type AbstractLife <: AbstractCellular end

@with_kw struct Life{N} <: AbstractLife
    neighborhood::N = RadialNeighborhood{:moore}(; overflow=Wrap())
    B::Array{Int,1} = [3]
    S::Array{Int,1} = [2,3]
end

"""
Rule for game-of-life style cellular automata.
"""
rule(model::AbstractLife, state, args...) = begin
    cc = neighbors(model.neighborhood, state, args...)
    active = cc in model.B || (state == one(state) && cc in model.S)
end
