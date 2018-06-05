module Cellular

import Base.show

using Parameters, Mixers, Unitful, Requires

include("neighborhoods.jl")
include("output.jl")
include("rules.jl")
include("framework.jl")

export rule, 
       automate!,
       generations,
       rule,
       sim!,
       MixedDispersal,
       update_view,
       Neighborhood, Neighborhood1D, Neighborhood2D,
       RadialNeighborhood,
       MooreNeighborhood,
       VonNeumannNeighborhood,
       RotVonNeumannNeighborhood,
       CustomNeighborhood,
       MultiNeighborhood,
       DispersalNeighborhood,
       Life,
       Skip,
       Wrap,
       TkOutput,
       GIfOutput
end
