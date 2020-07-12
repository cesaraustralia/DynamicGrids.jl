# DynamicGrids.jl

```@docs
DynamicGrids
```

## Examples

While this package isn't designed or optimised specifically to run the game of
life, it's a simple demonstration of what it can do. This example runs a
game of life and displays it in a REPLOutput.


```@example
using DynamicGrids, Distributions

# Build a random starting grid
init = Bool.(rand(Binomial(1, 0.5), 70, 70))

# Use the default game of life model
model = Ruleset(Life())

# Use an output that shows the cellular automata as blocks in the REPL
output = REPLOutput(init; tspan=1:50, fps=5)

sim!(output, model)
```

More life-like examples:

```julia
# Morley
sim!(output, Ruleset(Life(b=[3,6,8], s=[2,4,5]))

# 2x2
sim!(output, Ruleset(Life(b=[3,6], s=[1,2,5])))

# Dimoeba
init1 = round.(Int8, max.(0.0, rand(70,70)))
sim!(output, Ruleset(Life(b=[3,5,6,7,8], s=[5,6,7,8]); init=init1))

## No death
sim!(output, Ruleset(Life(b=[3], s=[0,1,2,3,4,5,6,7,8])))

## 34 life
sim!(output, Ruleset(Life(b=[3,4], s=[3,4])); init=init, fps=10)

# Replicator
init2 = round.(Int8, max.(0.0, rand(70,70)))
init2[:, 1:30] .= 0
init2[21:50, :] .= 0
sim!(output, Ruleset(Life(b=[1,3,5,7], s=[1,3,5,7])); init=init2)
```


## Rules

Rules define simulation behaviour. They hold data relevant to the simulation,
and trigger dispatch of particular [`applyrule`](@ref) or [`applyrule!`](@ref) methods.
Rules can be chained together arbitrarily to make composite simulations across
any number of grids.

```@docs
Ruleset
Rule
Chain
CellRule
Cell
NeighborhoodRule
Neighbors
Life
ManualRule
Manual
ManualNeighborhoodRule
```

```@docs
applyrule
applyrule!
```

## Neighborhoods

Neighborhoods define a pattern of cells surrounding the current cell,
and how they are combined to update the value of the current cell.

```@docs
Neighborhood
AbstractRadialNeighborhood
Moore
VonNeumann
Positional
LayeredPositional
```

```@docs
neighbors
sumneighbors
mapsetneighbor!
setneighbor!
```


## Output

### Output Types and Constructors

```@docs
Output
ArrayOutput
GraphicOutput
REPLOutput
ImageOutput
GifOutput
```

```@docs
DynamicGrids.Extent
DynamicGrids.GraphicConfig
DynamicGrids.ImageConfig
```

### Grid processors

```@docs
GridProcessor
SingleGridProcessor
SparseOptInspector
ColorProcessor
MultiGridProcessor
ThreeColorProcessor
LayoutProcessor
Greyscale
Grayscale
TextConfig
```

### Gifs

```@docs
savegif
```

## Ruleset config

### Overflow

```@docs
Overflow
WrapOverflow
RemoveOverflow
```

### Optimisation

```@docs
PerformanceOpt
NoOpt
SparseOpt
```


## Internal data handling

Simdata and Griddata objects are used to manage the simulation
and provide rules with any data they need.

```@docs
SimData
GridData
ReadableGridData
WritableGridData
```

# Methods

```@autodocs
Modules = [DynamicGrids]
Order   = [:function]
```
