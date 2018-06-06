# Cellular

[![Build Status](https://travis-ci.org/rafaqz/Cellular.jl.svg?branch=master)](https://travis-ci.org/rafaqz/Cellular.jl)

[![Coverage Status](https://coveralls.io/repos/rafaqz/Cellular.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/rafaqz/Cellular.jl?branch=master)

[![codecov.io](http://codecov.io/github/rafaqz/Cellular.jl/coverage.svg?branch=master)](http://codecov.io/github/rafaqz/Cellular.jl?branch=master)

Cellular is a generalised, modular framework for cellular automata and other
cellular models.

It's currently under development, and likely to change regularly at this stage.


Running a dispersal simulation:

```julia
using Cellular
using Tk

growthlimits = your_2d_array

# define the model
model = Dispersal(layers=SuitabilityLayer(growthlimits))

# define the source array
source = zeros(Int8, size(growthlimits))

# seed it
source[24, 354] = 1

# run the simulation
sim!(source, model) 
```

Running cellular automata:

```julia

# build a random starting grid
source = round.(Int8, max.(0.0, rand(-4.0:0.1:1.0, 400,400)))

# use the default game of life model
model = Life()

sim!(source, model)
```
