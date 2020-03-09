"""
Rule for game-of-life style cellular automata. This is a demonstration of 
Cellular Automata more than a seriously optimised game of life rule.

Cells becomes active if it is empty and the number of neightbors is a number in
the b array, and remains active the cell is active and the number of neightbors is
in the s array.

Returns: boolean

## Examples (gleaned from CellularAutomata.jl)

```julia
# Life. 
init = round.(Int64, max.(0.0, rand(-3.0:0.1:1.0, 300,300)))
output = REPLOutput(init; fps=10, color=:red)
sim!(output, rule, init; tspan=(1, 1000)

# Dimoeba
init = rand(0:1, 400, 300)
init[:, 100:200] .= 0
output = REPLOutput{:braile}(init; fps=25, color=:blue)
sim!(output, Ruleset(Life(b=(3,5,6,7,8), s=(5,6,7,8))), init; tspan=(1, 1000))

# Replicator
init = fill(1, 300,300)
init[:, 100:200] .= 0
init[10, :] .= 0
output = REPLOutput(init; fps=60, color=:yellow)
sim!(output, Ruleset(Life(b=(1,3,5,7), s=(1,3,5,7))), init; tspan=(1, 1000))
```

$(FIELDDOCTABLE)
"""
@description @limits @flattenable struct Life{W,R,K,N,B,S} <: NeighborhoodRule{W,R,K}
    neighborhood::N | false | nothing | "Any Neighborhood"
    b::B            | true  | (0, 8)  | "Array, Tuple or Iterable of integers to match neighbors when cell is empty"
    s::S            | true  | (0, 8)  | "Array, Tuple or Iterable of integers to match neighbors cell is full"
end
Life(;key=:_default_, read=key, write=key, neighborhood=RadialNeighborhood{1}(), b=(3, 3), s=(2, 3)) =
    Life{write,read,key}(neighborhood, b, s)

applyrule(rule::Life, data, state, index, buf) = begin
    sum = sumneighbors(rule.neighborhood, buf, state)
    # Check if neighborhood sum matches rule for the current state
    if sum in (rule.b, rule.s)[state+1]
        oneunit(state)
    else
        zero(state)
    end
end
