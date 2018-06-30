# Cellular.jl

```@docs
Cellular
```

## Example

This example runs a game of life simulation, and uses the REPLOutput to print the 
frame directly in the REPL. You could instead use `output = GtkOutput(init)` for animation.

```@example
using Cellular

# Build a random starting grid
init = round.(Int8, max.(0.0, rand(-2.0:0.1:1.0, 70,70)))

# Use the default game of life model
model = Life()

# Use an output that shows the cellular automata in the REPL
output = REPLOutput(init)

sim!(output, model, init; time=1:5)
```

These are some more life-like examples (gleaned from CellularAutomata.jl)

```julia
# Morley
sim!(output, Life(b=[3,6,8], s=[2,4,5]), init; pause=0.1)

# 2x2
sim!(output, Life(b=[3,6], s=[1,2,5]), init; pause=0.05)

# Dimoeba
init1 = round.(Int8, max.(0.0, rand(70,70)))
sim!(output, Life(b=[3,5,6,7,8], s=[5,6,7,8]), init1; pause=0.1)

## No death
sim!(output, Life(b=[3], s=[0,1,2,3,4,5,6,7,8]), init; pause=0.1)

## 34 life
sim!(output, Life(b=[3,4], s=[3,4]), init; pause=0.1)

# Replicator
init2 = round.(Int8, max.(0.0, rand(70,70)))
init2[:, 1:30] .= 0
init2[21:50, :] .= 0
sim!(output, Life(b=[1,3,5,7], s=[1,3,5,7]), init2; pause=0.1)
```

## Models and rules

Models define modelling behaviour. They hold data  relevant to the simulation,
and trigger dispatch of particular [`rule`](@ref) methods. Models can be chained
together arbitrarily to make composite simulations.

```@docs
rule

AbstractModel
AbstractPartialModel
AbstractLife
Life
```

## Neighborhoods

Neighborhoods define a pattern of cells surrounding the current cell, 
and how they are combined to update the value of the current cell.

```@docs
neighbors

AbstractNeighborhood
AbstractRadialNeighborhood
RadialNeighborhood
AbstractCustomNeighborhood
CustomNeighborhood
MultiCustomNeighborhood
```

## Simulations

```@docs
sim!
```

## Output

```@docs
AbstractOutput
AbstractArrayOutput
ArrayOutput
REPLOutput
GtkOutput
PlotsOutput
```

## Overflow

Your grids have edges. When neighborhood or spotting activities overflow past edge, 
you need a rule for deciding what to do.

```@docs
AbstractOverflow
Wrap
Skip
```

# Customisation

These functions (and any others those already listed) can all be overridden or 
have methods added to them to change simulation behaviour. Preferably create your 
own type of Model, Neighborhood or Output, and add methods of these functions that 
dispatch on those types. If your new times and methods add broadly useful functionality, 
consider making it publicly available by making pull request, or creating your own 
package that depends on Cellular.jl.

## Framework

```@docs
broadcastrules!
automate!
```

## Neighborhoods

```@docs
inbounds
inhood
```

## Output

```@docs
update_output
process_image
```
