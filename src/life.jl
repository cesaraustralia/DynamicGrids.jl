"""
$(TYPEDEF)
Triggers dispatch on rule  for game of life simulations. Models that extend
this should replicate the fields for [`Life`](@ref).
"""
abstract type AbstractLife <: AbstractModel end

"""
$(TYPEDEF)
Game of life style cellular automata.

### Fields:
- `neighborhood::AbstractNeighborhood`: The default is a `:moore` 
  [`RadialNeighborhood`](@ref) with [`Wrap`](@ref) overflow 
- `b`: Array or Tuple of integers to match neighbors when cell is empty Default = [3] 
- `s`: Array, Tuple or Iterable of integers to match neighbors when cell is full. The default is [2,3]
"""
@with_kw struct Life{N,B,S} <: AbstractLife
    neighborhood::N = RadialNeighborhood(; typ=:moore, radius=1, overflow=Wrap())
    b::B = [3]
    s::S = [2,3]
end

"""
    rule(model::AbstractLife, state, args...) = begin
Rule for game-of-life style cellular automata.

Cell value is flipped if cell is empty and the bumber of neightbors is in 
the b array, or if the cell is full and the bumber of neightbors is in the s array.

Only the model and state arguments are used.

Returns: boolean.
"""
rule(model::AbstractLife, state, args...) = begin
    cc = neighbors(model.neighborhood, state, args...)
    active = cc in model.b || (state == one(state) && cc in model.s)
end
