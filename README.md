# DynamicGrids

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/dev)
[![Build Status](https://travis-ci.org/cesaraustralia/DynamicGrids.jl.svg?branch=master)](https://travis-ci.org/cesaraustralia/DynamicGrids.jl) 
[![codecov.io](http://codecov.io/github/cesaraustralia/DynamicGrids.jl/coverage.svg?branch=master)](http://codecov.io/github/cesaraustralia/DynamicGrids.jl?branch=master)

DynamicGrids is a generalised framework for building high-performance grid-based spatial models, including celluar automata, but also allowing arbitrary behviours such as long distance jumps and interactions between multiple grids. It is extended by [Dispersal.jl](https://github.com/cesaraustralia/Dispersal.jl) for modelling organism dispersal processes.

![Dispersal quarantine](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/dispersal_quarantine.gif)

*A dispersal simulation with quarantine interactions, using Dispersal.jl, custom rules and the 
GtkOuput from [DynamicGridsGtk](https://github.com/cesaraustralia/DynamicGridsGtk.jl). 
Note that this is indicative of the real-time frame-rate on a laptop.*

A DynamicGrids.jl simulation is run with a script like this one
running the included game of life model `Life()`:

```julia
using DynamicGrids, Crayons

init = rand(Bool, 150, 200)
output = REPLOutput(init; tspan=1:200, fps=30, color=Crayon(foreground=:red, background=:black, bold=true))
sim!(output, Life())
```

![REPL life](https://github.com/cesaraustralia/DynamicGrids.jl/blob/media/life.gif?raw=true)

*A game of life simulation being displayed directly in a terminal.*


# Concepts

The framework is highly customisable, but there are some central ideas that define
how a simulation works: *rules* and *interactions*, *init* arrays and *outputs*.


## Rules

Rules hold the parameters for running a simulation. Each rule triggers a
specific `applyrule` method that operates on each of the active cells in the grid.
Rules come in a number of flavours (outlined in the 
[docs](https://cesaraustralia.github.io/DynamicGrids.jl/stable/#Rules-1)), which allow
assumptions to be made about running them that can greatly improve performance.
Rules are added to a `Ruleset`, with some additional parameters:

```
ruleset = Ruleset(Life(2, 3); opt=SparseOpt())
```

Multiple models can be combined in a `Ruleset`. Each rule will be run for the
whole grid, in sequence, using appropriate optimisations depending on the parent
types of each rule:

```julia
ruleset = Ruleset(rule1, rule2; timestep=Day(1), opt=SparseOpt())
```


For better performance (often ~2x or more), models included in a `Chain` object will be
combined into a single model, using only one array read and write. This
optimisation is limited to `CellRule`, or a `NeighborhoodRule`
followed by `CellRule`. If the `@inline` compiler macro is used on all
`applyrule` methods, all rules in a `Chain` will be compiled together into a single, 
efficient function call.

```julia
ruleset = Ruleset(rule1, Chain(rule2, rule3, rule4))
```

A `Ruleset` can hold rules that act on multiple grids. These may either run side
by side independently (say for live comparative analysis), or may interact.


## Init

`init` may be any `AbstractArray` or a `NamedTuple` of `AbstractArray`, 
It contains whatever initialisation data is required to start the simulation. 
The array type, size and element type of the `init` object determine the types
used in the simulation, as well as providing the initial conditions:

```juli
init = rand(Float32, 100, 100)
```

An init array can be attached to a `Ruleset`: 

```
ruleset = Ruleset(Life(); init=init)
```

or passed into a simulation, where it will take preference over the `Ruleset` init:

```
sim!(output, rulset; init=init)
```

For multiple grids, `init` is a `NamedTuple` of equal-sized arrays
matching the names given to each `Ruleset` :

```julia
init = (predator=rand(100, 100), prey=(rand(100, 100))
```

Handling and passing of the correct arrays is automated by DynamicGrids.jl.
`Rule`s must specify which grids they require in what order, using the
first two (`R` and `W`) type parameters. 


Dimensional or spatial init arrays from
[DimensionalData.jl](https://github.com/rafaqz/DimensionalData.jl) of
[GeoData.jl](https://github.com/rafaqz/GeoData.jl) will propagate through the
model to return output with explicit dimensions. This will plot correctly as a
map using [Plots.jl](https://github.com/JuliaPlots/Plots.jl), to which shape
files and observation points can be easily added.

## Output 

[Outputs](https://cesaraustralia.github.io/DynamicGrids.jl/stable/#Output-1)
are ways of storing or viewing a simulation. They can be used
interchangeably depending on your needs: `ArrayOutput` is a simple storage
structure for high performance-simulations. As with most outputs, it is
initialised with the init array, but in this case it also requires the number
of simulation frames to preallocate before the simulation runs.

```julia
output = ArrayOutput(init; tspan=1:10)
```

The `REPLOutput` shown above is an inbuilt `GraphicOutput` that can be useful for checking a
simulation when working in a terminal or over ssh:

```julia
output = REPLOutput(init; tspan=1:100)
```

`ImageOutput` is the most complex class of outputs, allowing full color visual
simulations using COlorSchemes.jl. It can also display interactions using color 
composites or layouts, as shown above in the quarantine simulation.

[DynamicGridsInteract.jl](https://github.com/cesaraustralia/DynamicGridsInteract.jl)
provides simulation interfaces for use in Juno, Jupyter, web pages or electron
apps, with live interactive control over parameters.
[DynamicGridsGtk.jl](https://github.com/cesaraustralia/DynamicGridsGtk.jl) is a
simple graphical output for Gtk. These packages are kept separate to avoid
dependencies when being used in non-graphical simulations. 

Outputs are also easy to write, and high performance or applications may benefit
from writing a custom output to reduce memory use, such as running a loss function on the fly
instead of storing the array. Performance of DynamicGrids.jl is dominated by cache
interactions, and reducing memory use has significant positive effects. Custom 
[frame processors](https://cesaraustralia.github.io/DynamicGrids.jl/stable/#Frame-processors-1)
can also be written, which can help developing specialised visualisations.

## Example

This example implements a very simple forest fire model:



```julia
using DynamicGrids, DynamicGridsGtk, ColorSchemes, Colors

const DEAD, ALIVE, BURNING = 1, 2, 3

rule = let prob_combustion=0.0001, prob_regrowth=0.01
    Neighbors(RadialNeighborhood{1}()) do neighborhood, cell
        if cell == ALIVE
            if BURNING in neighborhood
                BURNING
            else
                rand() <= prob_combustion ? BURNING : ALIVE
            end
        elseif cell in BURNING
            DEAD
        else
            rand() <= prob_regrowth ? ALIVE : DEAD
        end
    end
end

# Set up the init array and output (using a Gtk window)
init = fill(ALIVE, 400, 400)
processor = ColorProcessor(scheme=ColorSchemes.rainbow, zerocolor=RGB24(0.0))
output = GtkOutput(init; tspan=1:200, fps=25, minval=DEAD, maxval=BURNING, processor=processor)

# Run the simulation
sim!(output, rule)

# Save the output as a gif
savegif("forestfire.gif", output)
```

![forestfire](https://user-images.githubusercontent.com/2534009/72052469-5450c580-3319-11ea-8948-5196d1c6fd33.gif)


Timing the simulation for 200 steps, the performance is quite good:

```julia
output = ArrayOutput(init; tspan=1:200)
@time sim!(output, ruleset)
 1.384755 seconds (640 allocations: 2.569 MiB)

# To save a gif of the ArrayOutput we need to pass in a processor and the min and max
# values used in the simulation:

savegif("forestfire.gif", output; minval=DEAD, maxval=BURNING, processor=processor)
```

## Alternatives

[Agents.jl](https://github.com/JuliaDynamics/Agents.jl) can also do cellular-automata style simulations. The design of Agents.jl is to iterate over a list of agents, instead of broadcasting over an array of cells. This approach is well suited to when you need to track the movement and details about individual agents throughout the simulation. 

However, for simple grid models where you don't need to track individuals, like the forest fire model above, DynamicGrids.jl is two orders of magnitude faster than Agents.jl, and provides better visualisation tools. If you are doing grid-based simulation and you don't need to track individual agents, DynamicGrids.jl is probably the best tool. For other use cases, try Agents.jl.
