# DynamicGrids

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/dev)
[![Build Status](https://travis-ci.org/cesaraustralia/DynamicGrids.jl.svg?branch=master)](https://travis-ci.org/cesaraustralia/DynamicGrids.jl) 
[![Build status](https://ci.appveyor.com/api/projects/status/hgapxluxfsypvptc?svg=true)](https://ci.appveyor.com/project/cesaraustralia/cellularautomatabase-jl)
[![Coverage Status](https://coveralls.io/repos/cesaraustralia/DynamicGrids.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/cesaraustralia/DynamicGrids.jl?branch=master) 
[![codecov.io](http://codecov.io/github/cesaraustralia/DynamicGrids.jl/coverage.svg?branch=master)](http://codecov.io/github/cesaraustralia/DynamicGrids.jl?branch=master)

DynamicGrids is a generalised modular framework for cellular automata and similar spatial models.

The framework is highly customisable, but there are some central ideas that define
how a simulation works: *rules*, *init* arrays and *outputs*.

Rules hold the configuration for a simulation, and trigger a specific `applyrule` method
that operates on each of the cells in the grid.
`applyrule`. Rules come in a number of flavours, which allows assumptions to be made
about running them that can greatly improve performance. Rules are chained together in
a `Ruleset` object.

The init array may be any AbstractArray, containing whatever initialisation data
is required to start the simulation. The Array type and element type of the init
array determine the types used in the simulation, as well as providing the initial conditions.

Outputs are ways of storing of viewing a simulation, and can be used
interchangeably depending on your needs.

A typical simulation is run with a script like:

```julia
init = my_array
rules = Ruleset(Life())
output = ArrayOutput(init)

sim!(output, rules; init=init)
```

Multiple models can be passed to `sim!` in a `Ruleset`. Each rule
will be run for the whole grid, in sequence.

```julia
sim!(output, Ruleset(rule1, rule2); init=init)
```

For better performance, models included in a tuple will be combined into a single model
(with only one array write). This is limited to `AbstractCellRule`, although
`AbstractNeighborhoodRule` may be used as the *first* model in the tuple.

```julia
sim!(output, Rules(rule1, (rule2, rule3)); init=init)
```

This package is extended by
[Dispersal.jl](https://github.com/cesaraustralia/Dispersal.jl) for modelling organism
dispersal.
[DynamicGridsInteract.jl](https://github.com/cesaraustralia/DynamicGridsInteract.jl) and
[DynamicGridsGtk.jl](https://github.com/cesaraustralia/DynamicGridsGtk.jl)
provide simulation interfaces for web pages/electron apps and for Gtk.
