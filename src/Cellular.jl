__precompile__(true)

module Cellular

using Parameters, Requires

include("output.jl")
include("framework.jl")
include("neighborhoods.jl")
include("life.jl")

export automate!, 
       sim!,
       AbstractOutput, 
       TkOutput, 
       GIfOutput,
       ArrayOutput,
       AbstractCellular,
       AbstractInPlaceCellular,
       Skip, 
       Wrap,
       AbstractNeighborhood,
       AbstractRadialNeighborhood, 
       RadialNeighborhood,
       AbstractCustomNeighborhood, 
       CustomNeighborhood, 
       MultiCustomNeighborhood,
       AbstractLife, 
       Life
end
