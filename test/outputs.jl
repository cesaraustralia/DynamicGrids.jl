using DynamicGrids, Test
using DynamicGrids: isshowable, frameindex, storeframe!, SimData

# Mostly outputs are tested in integration.jl
@testset "Output construction" begin
    init = [10.0 11.0
            0.0   5.0]

    output1 = ArrayOutput(init; tspan=1:1)
    ruleset = Ruleset(Life())

    @test frameindex(output1, 5) == 5 
    @test isshowable(output1, 5) == false

    # Test pushing new frames to an output
    update = [8.0 15.0;
              2.0  9.0]
    @test length(output1) == 1
    push!(output1, update)
    @test length(output1) == 2
    @test output1[2] == update
end
