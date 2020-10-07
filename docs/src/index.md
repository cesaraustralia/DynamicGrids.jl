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

### Rule methods and helpers

```@docs
DynamicGrids.applyrule
DynamicGrids.applyrule!
DynamicGrids.precalcrules
isinferred 
```

### Data objects and methods for use in `applyrule`

```@docs
SimData
DynamicGrids.aux
DynamicGrids.tspan
DynamicGrids.timestep
DynamicGrids.currenttimestep
DynamicGrids.currenttime
DynamicGrids.currentframe
DynamicGrids.frameindex
DynamicGrids.inbounds
DynamicGrids.isinbounds
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

### Methods for use with neighborhood rules and neighborhoods

```@docs
DynamicGrids.radius
DynamicGrids.neighbors
DynamicGrids.sumneighbors
DynamicGrids.mapsetneighbor!
DynamicGrids.setneighbor!
DynamicGrids.allocbuffers
DynamicGrids.hoodsize
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

### Internal components and methods for outputs

These are used for defining your own outputs and `GridProcessors`, 
not for general scripting.

```@docs
DynamicGrids.Extent
DynamicGrids.GraphicConfig
DynamicGrids.ImageConfig
DynamicGrids.storeframe!
DynamicGrids.showframe
DynamicGrids.showimage
DynamicGrids.isasync
DynamicGrids.isshowable
DynamicGrids.isstored
DynamicGrids.initialise
DynamicGrids.delay
DynamicGrids.finalise
DynamicGrids.grid2image
DynamicGrids.rendertext!
DynamicGrids.rendertime!
DynamicGrids.rendername!
DynamicGrids.normalise
DynamicGrids.rgb
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

These methods and objects are all subject to change until version 1.0.

```@docs
DynamicGrids.GridData
DynamicGrids.ReadableGridData
DynamicGrids.WritableGridData
DynamicGrids.runsim!
DynamicGrids.simloop!
DynamicGrids.sequencerules!
DynamicGrids.maprule!
DynamicGrids.optmap
DynamicGrids.readgrids
DynamicGrids.writegrids
DynamicGrids.ismasked
DynamicGrids.getreadgrids
DynamicGrids.combinegrids
DynamicGrids.replacegrids
DynamicGrids.filter_readstate
DynamicGrids.filter_writestate
DynamicGrids.update_chainstate
```
