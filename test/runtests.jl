using DynamicGrids, Aqua, SafeTestsets

if VERSION >= v"1.5.0"
    # Amibiguities are not owned by DynamicGrids
    # Aqua.test_ambiguities([DynamicGrids, Base, Core])
    Aqua.test_unbound_args(DynamicGrids)
    Aqua.test_undefined_exports(DynamicGrids)
    Aqua.test_project_extras(DynamicGrids)
    # Aqua.test_stale_deps(DynamicGrids)
    Aqua.test_deps_compat(DynamicGrids)
    Aqua.test_project_toml_formatting(DynamicGrids)
end

@time @safetestset "rules" begin include("rules.jl") end
@time @safetestset "neighborhoods" begin include("neighborhoods.jl") end
@time @safetestset "simulationdata" begin include("simulationdata.jl") end
@time @safetestset "auxiliary" begin include("auxiliary.jl") end
@time @safetestset "utils" begin include("utils.jl") end
@time @safetestset "chain" begin include("chain.jl") end
@time @safetestset "condition" begin include("condition.jl") end
@time @safetestset "outputs" begin include("outputs.jl") end
@time @safetestset "chain" begin include("chain.jl") end
@time @safetestset "integration" begin include("integration.jl") end
@time @safetestset "objectgrids" begin include("objectgrids.jl") end
# TODO move these tests to 1.6 syntax, or test both?
if VERSION >= v"1.5.0" && VERSION < v"1.6.0"
    @time @safetestset "show" begin include("show.jl") end
end
# ImageMagick breaks in windows travis for some reason
if !Sys.iswindows() 
    @time @safetestset "image" begin include("image.jl") end
end
