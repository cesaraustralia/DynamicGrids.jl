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

@time @safetestset "generated" begin include("generated.jl") end
@time @safetestset "rules" begin include("rules.jl") end
@time @safetestset "neighborhoods" begin include("neighborhoods.jl") end
@time @safetestset "simulationdata" begin include("simulationdata.jl") end
@time @safetestset "utils" begin include("utils.jl") end
@time @safetestset "wrappers" begin include("wrappers/chain.jl") end
@time @safetestset "wrappers" begin include("wrappers/condition.jl") end
@time @safetestset "wrappers" begin include("wrappers/combine.jl") end
@time @safetestset "outputs" begin include("outputs.jl") end
@time @safetestset "transformed" begin include("transformed.jl") end
@time @safetestset "integration" begin include("integration.jl") end
@time @safetestset "objectgrids" begin include("objectgrids.jl") end
@time @safetestset "parametersources" begin include("parametersources.jl") end
@time @safetestset "show" begin include("show.jl") end
@time @safetestset "textconfig" begin include("textconfig.jl") end
# ImageMagick breaks in windows travis for some reason
if !Sys.iswindows() 
    @time @safetestset "image" begin include("image.jl") end
end
