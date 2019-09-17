using DynamicGrids, Test

# life glider sims

init =  [0 0 0 0 0 0;
         0 0 0 0 0 0;
         0 0 0 0 0 0;
         0 0 0 1 1 1;
         0 0 0 0 0 1;
         0 0 0 0 1 0]

test2 = [0 0 0 0 0 0;
         0 0 0 0 0 0;
         0 0 0 0 1 0;
         0 0 0 0 1 1;
         0 0 0 1 0 1;
         0 0 0 0 0 0]

test3 = [0 0 0 0 0 0;
         0 0 0 0 0 0;
         0 0 0 0 1 1;
         0 0 0 1 0 1;
         0 0 0 0 0 1;
         0 0 0 0 0 0]

test5 = [0 0 0 0 0 0;
         0 0 0 0 0 0;
         1 0 0 0 1 1;
         1 0 0 0 0 0;
         0 0 0 0 0 1;
         0 0 0 0 0 0]

ruleset = Ruleset(Life(); init=init, overflow=WrapOverflow())
output = ArrayOutput(init, 5)
sim!(output, ruleset; tstop=5)
output[1]
output[2]
output[3]
output[4]
output[5]

@testset "stored results match glider behaviour" begin
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
end

@testset "converted results match glider behaviour" begin
    output2 = ArrayOutput(output)
    @test output2[2] == test2
    @test output2[3] == test3
    @test output2[5] == test5
end

@testset "REPLOutput block works" begin
    output = REPLOutput(init; style=Block(), fps=100, store=true)
    output.frames
    sim!(output, ruleset; tstop=2)
    resume!(output, ruleset; tadd=5)
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
    # replay(output, ruleset)
end

@testset "REPLOutput braile works" begin
    output = REPLOutput(init; style=Braile(), fps=100, store=true)
    sim!(output, ruleset; tstop=2)
    resume!(output, ruleset; tadd=3)
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
    # replay(output, ruleset)
end
