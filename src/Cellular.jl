
"""
Cellular provides a framework for building grid based simulations. Everything
can be customised, but there are a few central idea that define how a Cellular
simulation works: models, output, and init arrays. 

The typical simulation is run with the command:

```julia
model = Life()

sim!(output, model, init)
```

Multiple models can be passed to  `sim!()` in a tuple.

```julia
sim!(output, (model1, model2), init)
```

The init array may be any AbstractArray, containing some whatever initialisation data
is required. Most rules two-dimensional arrays, but one dimensional arrays are also use for 
some Cellular automata. model and outputs can be types defined in Cellular, in 
packages that extend Cellular, or custom types.

# Exported types and methods

$(EXPORTS)
"""
module Cellular

using Parameters, Requires, DocStringExtensions, REPLTetris.Terminal
import Base.show


include("output.jl")
include("framework.jl")
include("neighborhoods.jl")
include("life.jl")
  
export automate!, 
       sim!,
       inbounds,
       show,
       AbstractModel,
       AbstractInPlaceModel,
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
       REPLOutput 

@require Tk begin
export TkOutput 
end

end

