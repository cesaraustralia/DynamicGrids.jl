# Cellular.jl

```@docs
Cellular
```

## Example

This example runs a game of life simulation, and uses the REPLOutput to print the final 
frame directly in the REPL. You could intsead use `output = TkOutput(init)` for live animation.

```@example
using Cellular

# Build a random starting grid
init = round.(Int8, max.(0.0, rand(-2.0:0.1:1.0, 30,70)))

# Use the default game of life model
model = Life()

# Use at output that shows life in the REPL
output = REPLOutput(init)

sim!(output, model, init; time=1:5)
```

These are some more life-like examples (gleaned from CellularAutomata.jl)

```julia
# Morley
sim!(output, Life(B=[3,6,8],S=[2,4,5]), init)

# 2x2
sim!(output, Life(B=[3,6],S=[1,2,5]), init)

# Replicator
sim!(output, Life(B=[1,3,5,7], S=[1,3,5,7]), init)

# Dimoeba
sim!(output, Life(B=[3,5,6,7,8], S=[5,6,7,8]), init)

## No death
sim!(output, Life(B=[3], S=[0,1,2,3,4,5,6,7,8]), init)

## 34 life
sim!(output, Life(B=[3,4], S=[3,4]), init)
```

## Models and rules

Models define modelling behaviour. They hold data  relevant to the simulation,
and trigger dispatch of particular [`rule`](@ref) methods. Models can be chained
together arbitrarily to make composite simulations.

```@docs
AbstractModel
AbstractInPlaceModel
AbstractLife
Life
```

## Neighborhoods

Some rules require neighborhoods as a field of the model. Neighborhoods define the 
pattern of cells that surrounds the current cell, and how they are summed to set 
the value of the current cell in a model. Neighborhoods are generally not used in
[`AbstractInPlaceModel`](@ref).

```@docs
AbstractNeighborhood
AbstractRadialNeighborhood
RadialNeighborhood
AbstractCustomNeighborhood
CustomNeighborhood
MultiCustomNeighborhood
```

## Overflow

Your grids have edges. When neighborhood or spotting activities overflow past edge, 
you need a rule for deciding what to do.

```@docs
AbstractOverflow
Wrap
Skip
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
TkOutput
```
Custom show() methods are available for some outputs.

```@docs
Base.show
```

# Customisation

These functions (and those already listed) can all be overridden to change
simulation behaviour. Preferably create your own type of Model, Neighborhood or Output, 
and add methods of these functions that dispatch on those types. If your
new times and methods add broadly useful functionality, consider making it
publicly available by making pull request, or creating your own package that
depends on Cellular.jl.

## Framework

```@docs
rule
broadcastrules!
automate!
```

## Neighborhoods

```@docs
neighbors
inbounds
inhood
```

## Output

```@docs
update_output
process_image
```
