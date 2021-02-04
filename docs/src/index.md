
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
DynamicGrids.SetRule
```

### CellRule

```@docs
CellRule
Cell
CopyTo
Chain
```

### NeighborhoodRule

```@docs
NeighborhoodRule
Neighbors
Convolution
Life
```

### SetCellRule

```@docs
SetCellRule
SetCell
```

### SetNeighborhoodRule

```@docs
SetNeighborhoodRule
SetNeighbors
```

### SetGridRule

```@docs
SetGridRule
SetGrid
```

### Parameter sources

```@docs
Aux
Grid
```

## Custom Rule interface and helpers

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

These are especially useful with [`SetNeighborhoodRule`](@ref).

```@docs
DynamicGrids.radius
DynamicGrids.neighbors
DynamicGrids.positions
DynamicGrids.offsets
```

## Atomic methods for SetCellRule and SetNeighborhoodRule

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

### Image generators

```@docs
ImageGenerator
Image
Layout
```

### Color schemes

Schemes from Colorschemes.jl can be used for the `scheme` argument to `ImageOutput`, 
`ImageGenerator`s. `Greyscale` control over the band of grey used, and is very fast. 
`ObjectScheme` is the default.

```@docs
ObjectScheme
Greyscale
Grayscale
```

### Saving gifs

```@docs
savegif
```

### `Output` interface

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

### `ImageOutput` components and interface

Also uses `Output` and `GraphicOutput` interfaces.

```@docs
DynamicGrids.ImageConfig
DynamicGrids.imageconfig
DynamicGrids.showimage
DynamicGrids.grid_to_image!
DynamicGrids.cell_to_pixel
DynamicGrids.to_rgb
```
