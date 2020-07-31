"""
    Life(neighborhood, birth=3, sustain=(2, 3))

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
sim!(output, Ruleset(Life(birth=[3,6,8], sustain=[2,4,5]))

# 2x2
sim!(output, Ruleset(Life(birth=[3,6], sustain=[1,2,5])))

# Dimoeba
init = rand(0:1, 400, 300)
init[:, 100:200] .= 0
output = REPLOutput{:braile}(init; fps=25, color=:blue)
sim!(output, Life(birth=(3,5,6,7,8), sustain=(5,6,7,8))))

## No death
sim!(output, Life(birth=[3], sustain=[0,1,2,3,4,5,6,7,8]))

## 34 life
sim!(output, Life(birth=[3,4], sustain=[3,4]))

# Replicator
init = fill(1, 300,300)
init[:, 100:200] .= 0
init[10, :] .= 0
output = REPLOutput(init; tspan=(1, 1000), fps=60, color=:yellow)
sim!(output, Life(birth=(1,3,5,7), sustain=(1,3,5,7)))
```

![REPL Life](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/life.gif)
"""
@default @flattenable @bounds @description struct Life{R,W,N,B,S,L} <: NeighborhoodRule{R,W}
    neighborhood::N | Moore(1) | false | nothing | "Any Neighborhood"
    birth::B        | 3        | true  | (0, 8)  | "Array, Tuple or Iterable of integers to match neighbors when cell is empty"
    sustain::S      | (2, 3)   | true  | (0, 8)  | "Array, Tuple or Iterable of integers to match neighbors cell is full"
    lookup::L       | _        | false | _       | _
    Life{R,W,N,B,S,L}(neighborhood::N, birth::B, sustain::S, lookup::L) where {R,W,N,B,S,L} = begin
        lookup = Tuple(i in birth for i in 0:8), Tuple(i in sustain for i in 0:8)
        new{R,W,N,B,S,typeof(lookup)}(neighborhood, birth, sustain, lookup)
    end
end
Life(neighborhood, birth, sustain) = 
    Life(neighborhood, birth, sustain, nothing) 
Life{R,W}(neighborhood, birth, sustain) where {R,W} = 
    Life{R,W}(neighborhood, birth, sustain, nothing) 


"""
    applyrule(data::SimData, rule::Life, state, I)

Applies game of life rule to current cell, returning `Bool`.
"""
applyrule(data::SimData, rule::Life, state, I) =
    rule.lookup[state + 1][sum(neighbors(rule)) + 1]
