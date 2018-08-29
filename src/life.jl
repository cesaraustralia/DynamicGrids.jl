"""
Triggers dispatch on rule  for game of life simulations. Models that extend
this should replicate the fields for [`Life`](@ref).
"""
abstract type AbstractLife <: AbstractModel end

" Game-of-life style cellular automata. "
@limits @flattenable @with_kw struct Life{N,B,S} <: AbstractLife
    # "An AbstractNeighborhood. RadialNeighborhood's are common for Cellular Automata."
    neighborhood::N = RadialNeighborhood(; typ=:moore, radius=1, overflow=Wrap()) | false | _
    # "Array, Tuple or Iterable of integers to match neighbors when cell is empty."
    b::B = (3,)   | true | (1, 9)
    # "Array, Tuple or Iterable of integers to match neighbors cell is full."
    s::S = (2, 3) | true | (1, 9)
end

"""
    rule(model::AbstractLife, state, args...)
Rule for game-of-life style cellular automata.

The cell becomes active if it is empty and the number of neightbors is a number in
the b array, and remains active the cell is active and the number of neightbors is
in the s array.

Returns: boolean

## Examples (gleaned from CellularAutomata.jl)

Use the arrow keys to scroll around, or zoom out if your terminal can do that!

```julia
# Life. 
init = round.(Int64, max.(0.0, rand(-3.0:0.1:1.0, 300,300)))
output = REPLOutput{:block}(init; fps=10, color=:red)
sim!(output, model, init; time=1000)

# Dimoeba
init = rand(0:1, 400, 300)
init[:, 100:200] .= 0
output = REPLOutput{:braile}(init; fps=25, color=:blue)
sim!(output, Models(Life(b=(3,5,6,7,8), s=(5,6,7,8))), init; time=1000)

# Replicator
init = fill(1, 300,300)
init[:, 100:200] .= 0
init[10, :] .= 0
output = REPLOutput{:block}(init; fps=60, color=:yellow)
sim!(output, Models(Life(b=(1,3,5,7), s=(1,3,5,7))), init; time=1000)
```

"""
rule(model::AbstractLife, state, args...) = begin
    # Sum neighborhood
    cc = neighbors(model.neighborhood, model, state, args...)
    # Determine next state based on current state and neighborhood total
    if state == zero(state) 
        for i = 1:length(model.b)
            if model.b[i] == cc
                return oneunit(state)
            end
        end
        return zero(state)
    else 
        for i = 1:length(model.s)
            if model.s[i] == cc
                return oneunit(state)
            end
        end
        return zero(state)
    end
end
