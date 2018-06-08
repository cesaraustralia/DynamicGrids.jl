module Cellular

import Base.show

using Parameters, Mixers, Unitful, Requires, Tk, Cairo

include("types.jl")
include("framework.jl")
include("rules.jl")
include("neighborhoods.jl")
include("dispersal.jl")
include("output.jl")

export automate!,
       sim!,
       exponential,
       # more dispersal kernel function here
       Neighborhood, Neighborhood1D, Neighborhood2D,
       RadialNeighborhood,
       MooreNeighborhood,
       VonNeumannNeighborhood,
       RotVonNeumannNeighborhood,
       CustomNeighborhood,
       MultiNeighborhood,
       DispersalNeighborhood,
       LongDispersal,
       ShortDispersal,
       Dispersal,
       Life,
       Skip,
       Wrap,
       TkOutput,
       GIfOutput,
       PopSuitLayers,
       SuitabilityLayer
end
