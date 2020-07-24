"""
Rule for game-of-life style cellular automata. This is a demonstration of 
Cellular Automata more than a seriously optimised game of life rule.

Cells becomes active if it is empty and the number of neightbors is a number in
the b array, and remains active the cell is active and the number of neightbors is
in the s array.

## Examples (gleaned from CellularAutomata.jl)

```@example
# Life. 
using DynamicGrids, Distributions
init = Bool.(rand(Binomial(1, 0.5), 70, 70))
output = REPLOutput(init; tspan=(1, 1000), fps=10, color=:red)

# Morley
sim!(output, Ruleset(Life(b=[3,6,8], s=[2,4,5]))

# 2x2
sim!(output, Ruleset(Life(b=[3,6], s=[1,2,5])))

# Dimoeba
init = rand(0:1, 400, 300)
init[:, 100:200] .= 0
output = REPLOutput{:braile}(init; fps=25, color=:blue)
sim!(output, Life(b=(3,5,6,7,8), s=(5,6,7,8))))

## No death
sim!(output, Life(b=[3], s=[0,1,2,3,4,5,6,7,8]))

## 34 life
sim!(output, Life(b=[3,4], s=[3,4]))

# Replicator
init = fill(1, 300,300)
init[:, 100:200] .= 0
init[10, :] .= 0
output = REPLOutput(init; tspan=(1, 1000), fps=60, color=:yellow)
sim!(output, Life(b=(1,3,5,7), s=(1,3,5,7)))
```

"""
@default @flattenable @bounds @description struct Life{R,W,N,B,S,L} <: NeighborhoodRule{R,W}
    neighborhood::N | Moore(1) | false | nothing | "Any Neighborhood"
    b::B            | (3, 3)   | true  | (0, 8)  | "Array, Tuple or Iterable of integers to match neighbors when cell is empty"
    s::S            | (2, 3)   | true  | (0, 8)  | "Array, Tuple or Iterable of integers to match neighbors cell is full"
    lookup::L       | _        | false | _       | _
    Life{R,W,N,B,S,L}(neighborhood::N, b::B, s::S, lookup::L) where {R,W,N,B,S,L} = begin
        lookup = Tuple(i in b for i in 0:8), Tuple(i in s for i in 0:8)
        new{R,W,N,B,S,typeof(lookup)}(neighborhood, b, s, lookup)
    end
end
Life(neighborhood, b, s) = Life(neighborhood, b, s, nothing) 
Life{R,W}(neighborhood, b, s) where {R,W} = Life{R,W}(neighborhood, b, s, nothing) 


"""
    applyrule(data::SimData, rule::Life, state, I)

Applies game of life rule to current cell, returning `Bool`.
"""
applyrule(data::SimData, rule::Life, state, I) =
    rule.lookup[state + 1][sum(neighbors(rule)) + 1]
