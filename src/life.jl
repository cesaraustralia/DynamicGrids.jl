"""
Triggers dispatch on rule  for game of life simulations. Models that extend
this should replicate the fields for [`Life`](@ref).
"""
abstract type AbstractLife <: AbstractModel end

" Game-of-life style cellular automata. "
@limits @flattenable @with_kw struct Life{N,B,S} <: AbstractLife
    # "An AbstractNeighborhood. RadialNeighborhood's are common for Cellular Automata."
    neighborhood::N = RadialNeighborhood(; typ=:moore, radius=1, overflow=Wrap()) | Exclude() | _
    # "Array, Tuple or Iterable of integers to match neighbors when cell is empty."
    b::B = (3)    | Include() | (1, 9)
    # "Array, Tuple or Iterable of integers to match neighbors cell is full."
    s::S = (2, 3) | Exclude() | (1, 9)
end

"""
    rule(model::AbstractLife, state, args...)
Rule for game-of-life style cellular automata.

The cell becomes active if it is empty and the number of neightbors is a number in
the b array, and remains active the cell is active and the number of neightbors is
in the s array.

Returns: boolean
"""
rule(model::AbstractLife, state, args...) = begin
    # Sum neighborhood
    cc = neighbors(model.neighborhood, model, state, args...)
    # Determine next state based on current state and neighborhood total
    (state == zero(state) && cc in model.b) || (state == one(state) && cc in model.s)
end
