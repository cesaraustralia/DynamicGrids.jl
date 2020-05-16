using DynamicGrids, Test
using DynamicGrids: isshowable, gridindex, storegrid!, SimData

@testset "Output construction" begin
    init = [10.0 11.0
            0.0   5.0]

    output1 = ArrayOutput(init;
        starttime=7,
        stoptime=99,
    )
    ruleset = Ruleset(Life())

    @test gridindex(output1, 5) == 5 
    @test isshowable(output1, 5) == false

    # Test pushing new frames to an output
    update = [8.0 15.0;
              2.0  9.0]
    @test length(output1) == 1
    push!(output1, update)
    @test length(output1) == 2
    @test output1[2] == update

    # Test creting a new output from an existing output
    output2 = ArrayOutput(output1)
    @test length(output2) == 2
    @test output2[2] == update

    output3 = REPLOutput(output2; 
        fps=23,
        showfps=29,
        timestamp=12345,
        stampframe=4,
        store=false,
    )
    @test length(output3) == 2
    @test output3[2] == update

    output4 = REPLOutput(output3)
    @test length(output4) == 2
    @test output2[2] == update

    @test DynamicGrids.starttime(output4) == 7
    @test DynamicGrids.stoptime(output4) == 99
    @test DynamicGrids.fps(output4) == 23
    @test DynamicGrids.showfps(output4) == 29
    @test DynamicGrids.store(output4) == false
    @test DynamicGrids.timestamp(output4) == 12345
    @test DynamicGrids.stampframe(output4) == 4
end
