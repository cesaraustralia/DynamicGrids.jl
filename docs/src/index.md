# DynamicGrids.jl

```@docs
DynamicGrids
```

## Running simulations

```@docs
sim!
resume! 
```

## Rules

Rules define simulation behaviour. They hold data relevant to the simulation,
and trigger dispatch of particular [`applyrule`](@ref) or [`applyrule!`](@ref) methods.
Rules can be chained together arbitrarily to make composite simulations across
any number of grids.

```@docs
Ruleset
Rule
CellRule
Cell
NeighborhoodRule
Neighbors
Life
ManualRule
Manual
ManualNeighborhoodRule
Chain
```

```@docs
DynamicGrids.applyrule
DynamicGrids.applyrule!
DynamicGrids.precalcrules
isinferred 
```

### Simulation data and methods for use in `applyrule`

```@docs
SimData
DynamicGrids.radius
DynamicGrids.aux
DynamicGrids.timestep
DynamicGrids.currenttimestep
DynamicGrids.currenttime
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

### Methods for use with Neighborhood objects

```@docs
DynamicGrids.neighbors
DynamicGrids.sumneighbors
DynamicGrids.mapsetneighbor!
DynamicGrids.setneighbor!
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

### Output methods

```
DynamicGrids.storeframe!
DynamicGrids.showframe
DynamicGrids.showimage
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

[`SimData`](@ref) and [`GridData`](@ref) objects are used to 
manage the simulation and provide rules with any data they need.

These methods and objects are all subject to change.

```@docs
DynamicGrids.GridData
DynamicGrids.ReadableGridData
DynamicGrids.WritableGridData
DynamicGrids.sequencerules!
DynamicGrids.maprule!
DynamicGrids.optmap
DynamicGrids.readgrids
DynamicGrids.writegrids
DynamicGrids.getgrids
DynamicGrids.combinegrids
DynamicGrids.replacegrids
```
