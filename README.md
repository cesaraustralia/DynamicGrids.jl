# DynamicGrids

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/dev)
[![Build Status](https://travis-ci.org/cesaraustralia/DynamicGrids.jl.svg?branch=master)](https://travis-ci.org/cesaraustralia/DynamicGrids.jl) 
[![Buildcellularautomatabase status](https://ci.appveyor.com/api/projects/status/hgapxluxfsypvptc?svg=true)](https://ci.appveyor.com/project/rafaqz/dynamicgrids-jl)
[![Coverage Status](https://coveralls.io/repos/cesaraustralia/DynamicGrids.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/cesaraustralia/DynamicGrids.jl?branch=master) 
[![codecov.io](http://codecov.io/github/cesaraustralia/DynamicGrids.jl/coverage.svg?branch=master)](http://codecov.io/github/cesaraustralia/DynamicGrids.jl?branch=master)

DynamicGrids is a generalised modular framework for cellular automata and
similar grid-based spatial models.

The framework is highly customisable, but there are some central ideas that define
how a simulation works: *rules*, *init* arrays and *outputs*.

## Rules

Rules hold the parameters for running a simulation. Each rule triggers a
specific `applyrule` method that operates on each of the cells in the grid.
Rules come in a number of flavours (outlined in the docs), which allows
assumptions to be made about running them that can greatly improve performance.
Rules are joined in a `Ruleset` object and run in sequence.

## Init

The init array may be any `AbstractArray`, containing whatever initialisation
data is required to start the simulation. The array type and element type of the
init array determine the types used in the simulation, as well as providing the
initial conditions. An init array can be attached to a `Ruleset` or passed into
a simulation (the latter will take preference).

## Outputs 

Outputs (in `AbstractOuput`) are ways of storing of viewing a simulation. They
can be used interchangeably depending on your needs: `ArrayOutput` is a simple
storage structure for high performance-simulations. The `REPLOutput` can be useful
for checking a simulation when working in a terminal or over ssh.

[DynamicGridsInteract.jl](https://github.com/cesaraustralia/DynamicGridsInteract.jl)
provides simulation interfaces for use in Juno, Jupyter, web pages or electron
apps, with live interactive control over parameters.
[DynamicGridsGtk.jl](https://github.com/cesaraustralia/DynamicGridsGtk.jl) is a
simple graphical output for Gtk. These packages are kept separate to avoid
dependencies when being used in non-graphical simulations. Outputs are
also easy to write, and high performance or applications may benefit from
writing a custom output to reduce memory use, while custom frame processors can
help developing specialised visualisations.

## Simulations

A typical simulation is run with a script like:

```julia
init = my_array
rules = Ruleset(Life(); init=init)
output = ArrayOutput(init)

sim!(output, rules)
```

Multiple models can be passed to `sim!` in a `Ruleset`. Each rule will be run
for the whole grid, in sequence, using appropriate optimisations depending on
the parent types of the rules.

```julia
sim!(output, Ruleset(rule1, rule2); init=init)
```

For better performance (often ~2x), models included in a `Chain` object will be
combined into a single model, using only one array read and write. This
optimisation is limited to `AbstractCellRule`, or an `AbstractNeighborhoodRule`
followed by `AbstractCellRule`. If the `@inline` compiler macro is used on all
`applyrule` methods, rules in a `Chain` will be compiled together into a single
function call.

```julia
sim!(output, Rules(rule1, Chain(rule2, rule3)); init=init)
```

DynamicGrids.jl is extended by
[Dispersal.jl](https://github.com/cesaraustralia/Dispersal.jl) for modelling
organism dispersal. Dispersal.jl is a useful template for writing other
extensions, and includes many Rules, as well as a custom frame procesor for
display and output for better simulation performance.

## Future work

### Multi-entity simulations

Using the same architecture we can simulate multiple entities and their
interactions in a single simulations. This will involve using arrays of static
arrays (and LabelledArrays). Each field of these arrays may have custom rules or
similar rules with different parameters, anbd may also have rules that define
how they interact. This will enable previously unavailable multi-species,
multi-genome, multi age-class dispersal models in ecology, and likely other
applications in other fields. 

A DSL is being developed to write these complex models with a similar syntax,
that will also enable further performance optimisations.


