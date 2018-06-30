
"""
Cellular provides a framework for building grid based simulations. Everything
can be customised and added to, but there are some central idea that define how a Cellular
simulation works: _models_, _rules_ and _neighborhoods_. For input and output of data their are 
_init_ arrays and _outputs_. 

Models hold the configuration for the simulation, and trigger a specific `rule` method 
that operates on each of the cells in the grid. See [`AbstractModel`](@ref) and 
[`rule`](@ref). Rules often trigger [`neighbors`](@ref) methods that sum surrounding cell 
_neighborhoods_ ([`AbstractNeighborhood`](@ref)), such as Moore and Von Neumann neighborhoods.

Outputs are ways of storing of viewing the simulation, and can be used interchangeably 
depending on your needs. See [`AbstractOutput`](@ref).

The inititialisation array may be any AbstractArray, containing whatever initialisation data
is required to start the simulation. Most rules work on two-dimensional arrays, but one-dimensional 
arrays are also use for some Cellular automata. 

A typical simulation is run with a script like:

```julia
init = my_array
model = Life()
output = REPLOutput(init)

sim!(output, model, init)
```

Multiple models can be passed to  `sim!()` in a tuple, and each of their rules
will be run in order.

```julia
sim!(output, (model1, model2), init)
```

# Exported types and methods

$(EXPORTS)
"""
module Cellular

using Parameters, Requires, DocStringExtensions, REPLTetris.Terminal, Gtk, Cairo
import Base.show

# Documentation templates
@template TYPES =
    """
    $(TYPEDEF)
    $(DOCSTRING)
    $(FIELDS)
    """

include("output.jl")
include("framework.jl")
include("neighborhoods.jl")
include("life.jl")
  
export automate!, 
       sim!,
       inbounds,
       show,
       AbstractModel,
       AbstractPartialModel,
       AbstractLife, 
       Life,
       AbstractNeighborhood,
       AbstractRadialNeighborhood, 
       RadialNeighborhood,
       AbstractCustomNeighborhood, 
       CustomNeighborhood, 
       MultiCustomNeighborhood,
       AbstractOverflow,
       Skip, 
       Wrap,
       AbstractOutput, 
       AbstractArrayOutput, 
       ArrayOutput,
       GtkOutput,
       REPLOutput 

@require Plots begin
export PlotsOutput 
end

end

