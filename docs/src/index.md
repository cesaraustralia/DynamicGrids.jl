# DynamicGrids.jl

```@docs
DynamicGrids
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
AbstractPositional
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

### Internal components for outputs

```@docs
DynamicGrids.Extent
DynamicGrids.GraphicConfig
DynamicGrids.ImageConfig
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
