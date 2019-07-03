using SafeTestsets

@time @safetestset "neighborhoods" begin include("neighborhoods.jl") end
@time @safetestset "framework" begin include("framework.jl") end
@time @safetestset "common" begin include("common.jl") end
@time @safetestset "frame processing" begin include("frame_processing.jl") end
@time @safetestset "utils" begin include("utils.jl") end
@time @safetestset "integration" begin include("integration.jl") end
