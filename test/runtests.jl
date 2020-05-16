using SafeTestsets

@time @safetestset "rules" begin include("rules.jl") end
@time @safetestset "chain" begin include("chain.jl") end
@time @safetestset "neighborhoods" begin include("neighborhoods.jl") end
@time @safetestset "simulationdata" begin include("simulationdata.jl") end
@time @safetestset "utils" begin include("utils.jl") end
@time @safetestset "outputs" begin include("outputs.jl") end
@time @safetestset "integration" begin include("integration.jl") end
@time @safetestset "show" begin include("show.jl") end
# ImageMagick breaks in windows travis for some reason
if !Sys.iswindows() 
    @time @safetestset "image" begin include("image.jl") end
end
