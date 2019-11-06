# DynamicGrids

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/dev)
[![Build Status](https://travis-ci.org/cesaraustralia/DynamicGrids.jl.svg?branch=master)](https://travis-ci.org/cesaraustralia/DynamicGrids.jl) 
[![Buildcellularautomatabase status](https://ci.appveyor.com/api/projects/status/hgapxluxfsypvptc?svg=true)](https://ci.appveyor.com/project/rafaqz/dynamicgrids-jl)
[![Coverage Status](https://coveralls.io/repos/cesaraustralia/DynamicGrids.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/cesaraustralia/DynamicGrids.jl?branch=master) 
[![codecov.io](http://codecov.io/github/cesaraustralia/DynamicGrids.jl/coverage.svg?branch=master)](http://codecov.io/github/cesaraustralia/DynamicGrids.jl?branch=master)

DynamicGrids is a generalised modular framework for cellular automata and
similar grid-based spatial models. It is extended by
[Dispersal.jl](https://github.com/cesaraustralia/Dispersal.jl) for modelling
organism dispersal processes.

The framework is highly customisable, but there are some central ideas that define
how a simulation works: *rules*, *init* arrays and *outputs*.


## Rules, and Interactions

Rules hold the parameters for running a simulation. Each rule triggers a
specific `applyrule` method that operates on each of the cells in the grid.
Rules come in a number of flavours (outlined in the docs), which allows
assumptions to be made about running them that can greatly improve performance.
Rules are joined in a `Ruleset` object and run in sequence:

```
ruleset = Ruleset(Life(2, 3))
```

The `Rulset` wrapper seems a little redundant here, but multiple models can be
combined in a `Ruleset`. Each rule will be run for the whole grid, in sequence,
using appropriate optimisations depending on the parent types of each rule:

```julia
ruleset = Ruleset(rule1, rule2)
```

For better performance (often ~2x), models included in a `Chain` object will be
combined into a single model, using only one array read and write. This
optimisation is limited to `CellRule`, or an `NeighborhoodRule`
followed by `CellRule`. If the `@inline` compiler macro is used on all
`applyrule` methods, all rules in a `Chain` will be compiled together with the
looping code into a single, efficient function call.

```julia
ruleset = Ruleset(rule1, Chain(rule2, rule3))
```

A `MultiRuleset` holds, as the name suggests, multiple rulesets. These may
either run side by side independently (say for comparative analysis), or
interact using `Interaction` rules. An `Interaction` is a rule that operates on
multiple grids, linking multiple discrete `Ruleset`s into a larger model, such
as this hypothetical spatial predator/prey model:

```julia
MuliRuleset(rules=(predator=predatordispersal, prey=Chain(popgrowth, preydispersal)),
            interactions=(predation,))
```


## Init

The `init` array may be any `AbstractArray`, containing whatever initialisation
data is required to start the simulation. The array type, size and element type
of the `init` array determine the types used in the simulation, as well as
providing the initial conditions:

```juli
init = rand(Float32, 100, 100)
```

An `init` array can be attached to a `Ruleset`: 

```
ruleset = Ruleset(Life(); init=init)
```

or passed into a simulation, where it will take preference over the `Ruleset` init:

```
sim!(output, rulset; init=init)
```

For `MultiRuleset`, `init` is a `NamedTuple` of equal-sized arrays
matching the names given to each `Ruleset` :

```julia
init = (predator=rand(100, 100), prey=(rand(100, 100))
```

Handling and passing of the correct arrays is automated by DynamicGrids.jl.
`Interaction` rules must specify which grids they require in what order.


## Output 

Outputs are ways of storing or viewing a simulation. They can be used
interchangeably depending on your needs: `ArrayOutput` is a simple storage
structure for high performance-simulations. As with most outputs, it is
initialised with the `init` array, but in this case it also requires the number
of simulation frames to preallocate before the simulation runs.

```julia
output = ArrayOutput(init, 10)
```

The `REPLOutput` is a `GraphicOutput` that can be useful for checking a
simulation when working in a terminal or over ssh:

```julia
output = REPLOutput(init)
```

`ImageOutput` is the most complex class of outputs, allowing full color visual
simulations and even interactions.
[DynamicGridsInteract.jl](https://github.com/cesaraustralia/DynamicGridsInteract.jl)
provides simulation interfaces for use in Juno, Jupyter, web pages or electron
apps, with live interactive control over parameters.
[DynamicGridsGtk.jl](https://github.com/cesaraustralia/DynamicGridsGtk.jl) is a
simple graphical output for Gtk. These packages are kept separate to avoid
dependencies when being used in non-graphical simulations. 

Outputs are also easy to write, and high performance or applications may benefit
from writing a custom output to reduce memory use, while custom frame processors
can help developing specialised visualisations.


## Simulations

A typical simulation is run with a script like:

```julia
init = my_array
rules = Ruleset(Life(); init=init)
output = ArrayOutput(init, 10)

sim!(output, rules)
```

