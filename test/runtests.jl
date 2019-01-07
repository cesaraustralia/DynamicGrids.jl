using Revise, 
      Cellular,
      Test
import Cellular: rule, rule!, neighbors

setup(x) = x

# For manual testing on CUDA
# using CuArrays
# setup(x) = CuArray(x)

@testset "neighborhoods" begin include("neighborhoods.jl") end
@testset "framework" begin include("framework.jl") end
@testset "common" begin include("common.jl") end
@testset "integration" begin include("integration.jl") end
