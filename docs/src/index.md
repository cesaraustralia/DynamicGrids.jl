
```@docs
DynamicGrids
```

## Running simulations

```@docs
sim!
resume! 
```

## Rulesets

```@docs
AbstractRuleset
Ruleset
```

### Boundary conditions

```@docs
Boundary
Wrap
Remove
```

### Hardware selection

```@docs
DynamicGrids.Processor
DynamicGrids.CPU
SingleCPU
ThreadedCPU
CuGPU
```

### Performance optimisation

```@docs
PerformanceOpt
NoOpt
SparseOpt
```

## Rules

```@docs
Rule
CellRule
Cell
CopyTo
NeighborhoodRule
Neighbors
Convolution
Life
DynamicGrids.SetRule
SetCellRule
SetCell
SetNeighborhoodRule
SetNeighbors
SetGridRule
SetGrid
Chain
```

### Rules parameter sources

```@docs
Aux
Grid
```

### Custom Rule interface and helpers

```@docs
DynamicGrids.applyrule
DynamicGrids.applyrule!
DynamicGrids.precalcrule
isinferred 
```

### Objects and methods for use in `applyrule` and/or `precalcrule`

```@docs
DynamicGrids.SimData
DynamicGrids.GridData
DynamicGrids.ReadableGridData
DynamicGrids.WritableGridData
DynamicGrids.ismasked
DynamicGrids.inbounds
DynamicGrids.isinbounds
DynamicGrids.init
DynamicGrids.aux
DynamicGrids.mask
DynamicGrids.tspan
DynamicGrids.timestep
DynamicGrids.currenttimestep
DynamicGrids.currenttime
DynamicGrids.currentframe
```

## Neighborhoods

```@docs
Neighborhood
RadialNeighborhood
Moore
VonNeumann
Window
AbstractPositional
Positional
LayeredPositional
AbstractKernel
Kernel
```

### Methods for use with neighborhood rules and neighborhoods

```@docs
DynamicGrids.radius
DynamicGrids.neighbors
DynamicGrids.positions
DynamicGrids.offsets
```

## Atomic methods

Using these methods to modify grid values ensures cell independence, 
and also prevent race conditions with [`ThreadedCPU`](@ref) or [`CuGPU`].

```@docs
add!
sub!
min!
max!
and!
or!
xor!
```

## Output

### Output Types and Constructors

```@docs
Output
ArrayOutput
ResultOutput
GraphicOutput
REPLOutput
ImageOutput
GifOutput
```

### Saving gifs

```@docs
savegif
```


## `Output` interface

These are used for defining your own outputs and `GridProcessors`, 
not for general scripting.

```@docs
DynamicGrids.AbstractExtent
DynamicGrids.Extent
DynamicGrids.extent
DynamicGrids.isasync
DynamicGrids.storeframe!
DynamicGrids.isrunning
DynamicGrids.isshowable
DynamicGrids.isstored
DynamicGrids.initialise!
DynamicGrids.finalise!
```

### `GraphicOutput` interface

Also includes `Output` interface.

```@docs
DynamicGrids.GraphicConfig
DynamicGrids.graphicconfig
DynamicGrids.fps
DynamicGrids.setfps!
DynamicGrids.showframe
DynamicGrids.delay
DynamicGrids.initialisegraphics
DynamicGrids.finalisegraphics
```

### `ImageOutput` interface

Also includes `Output` and `GraphicOutput` interfaces.

```@docs
DynamicGrids.showimage
```

`ImageConfig`/`GridProcessor` interface

```@docs
DynamicGrids.ImageConfig
DynamicGrids.imageconfig
DynamicGrids.ImageProcessor
```

## Grid processors

```@docs
Greyscale
Grayscale
ImageGenerator
SingleGridImageGenerator
Image
MultiGridImageGenerator
Layout
SparseOptInspector
TextConfig
```

## Interface methods

```
DynamicGrids.grid_to_image!
DynamicGrids.cell_to_pixel
DynamicGrids.to_rgb
```
