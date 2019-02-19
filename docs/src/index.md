# Cellular.jl

```@docs
Cellular
```

## Index

```@contents
```

## Examples

While this package isn't designed or optimised specifically to run the game of
life, it's a simple example of what this package can do. This example runs a
game of life and displays it in a REPLOutput. You could instead use `output =
GtkOutput(init)` for animation in a GTK window.

```@example
using Cellular

# Build a random starting grid
init = round.(Int8, max.(0.0, rand(-2.0:0.1:1.0, 70,70)))

# Use the default game of life model
model = Models(Life())

# Use an output that shows the cellular automata as blocks in the REPL
output = REPLOutput{:block}(init; fps=100)

sim!(output, model, init; tstop=5)
```

More life-like examples (gleaned from CellularAutomata.jl):

```julia
# Morley
sim!(output, Models(Life(b=[3,6,8], s=[2,4,5])), init)

# 2x2
sim!(output, Models(Life(b=[3,6], s=[1,2,5])), init)

# Dimoeba
init1 = round.(Int8, max.(0.0, rand(70,70)))
sim!(output, Models(Life(b=[3,5,6,7,8], s=[5,6,7,8])), init1)

## No death
sim!(output, Models(Life(b=[3], s=[0,1,2,3,4,5,6,7,8])), init)

## 34 life
sim!(output, Models(Life(b=[3,4], s=[3,4])), init; fps=10)

# Replicator
init2 = round.(Int8, max.(0.0, rand(70,70)))
init2[:, 1:30] .= 0
init2[21:50, :] .= 0
sim!(output, Models(Life(b=[1,3,5,7], s=[1,3,5,7])), init2)
```


## Models and rules

Models define simulation behaviour. They hold data relevant to the simulation,
and trigger dispatch of particular [`rule`](@ref) or [`rule!`](@ref) methods.
Models can be chained together arbitrarily to make composite simulations.

### Types and Constructors

```@docs
AbstractModel
AbstractPartialModel
AbstractNeighborhoodModel
AbstractPartialNeighborhoodModel
AbstractCellModel
AbstractLife
Life
```

### Methods

```@docs
rule
rule!
```

## Neighborhoods

Neighborhoods define a pattern of cells surrounding the current cell, 
and how they are combined to update the value of the current cell.

### Types and Constructors

```@docs
AbstractNeighborhood
AbstractRadialNeighborhood
RadialNeighborhood
AbstractCustomNeighborhood
CustomNeighborhood
MultiCustomNeighborhood
```

### Methods

```@docs
neighbors
```

## Simulations

```@docs
sim!
resume!
```

## Output

### Output Types and Constructors

```@docs
AbstractOutput
ArrayOutput
REPLOutput
GtkOutput
```
```@docs
BlinkOuput
MuxServer
```

### Frame processors

```@docs
AbstractFrameProcessor
Greyscale
ColorZeros
process_image
```

### Methods

```@docs
savegif
replay
show_frame
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

Functions listed can be overridden or have methods added to them to modify
simulation behaviour. Preferably create your own types of Model, Neighborhood or
Output, and add methods for functions that dispatch on those types. If your new
times and methods add useful functionality, consider making it publicly
available by making pull request, or creating your own package that depends on
Cellular.jl.

These are some more low-level functions you may also want to understand, if not
actually modify extend.

## Framework

```@docs
run_model!
run_rule!
max_radius
radius
temp_neighborhood
inbounds
```
