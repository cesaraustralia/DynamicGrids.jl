using SafeTestsets

@time @safetestset "neighborhoods" begin include("neighborhoods.jl") end
@time @safetestset "mask" begin include("mask.jl") end
@time @safetestset "framework" begin include("framework.jl") end
@time @safetestset "outputs" begin include("outputs.jl") end
@time @safetestset "utils" begin include("utils.jl") end
@time @safetestset "integration" begin include("integration.jl") end
@time @safetestset "frame processing" begin include("frame_processing.jl") end
