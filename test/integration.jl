using CellularAutomataBase, Test

# life glider sims


init =  [0 0 0 0 0 0;
         0 0 0 0 0 0;
         0 0 0 0 0 0;
         0 0 0 1 1 1;
         0 0 0 0 0 1;
         0 0 0 0 1 0]
               
test =  [0 0 0 0 0 0;
         0 0 0 0 0 0;
         0 0 0 0 1 1;
         0 0 0 1 0 1;
         0 0 0 0 0 1;
         0 0 0 0 0 0]

test2 = [0 0 0 0 0 0;
         0 0 0 0 0 0;
         1 0 0 0 1 1;
         1 0 0 0 0 0;
         0 0 0 0 0 1;
         0 0 0 0 0 0]

rule = Ruleset(Life(); init=init, overflow=WrapOverflow())
output = ArrayOutput(init, 1000)
sim!(output, rule; tstop=5)

@testset "stored results match glider behaviour" begin
    @test output[3] == test
    @test output[5] == test2
end

@testset "converted results match glider behaviour" begin
    output2 = ArrayOutput(output)
    @test output2[3] == test
    @test output2[5] == test2
end

@testset "REPLOutput{:block} works" begin
    output = REPLOutput{:block}(init; fps=100, store=true)
    sim!(output, rule; tstop=2)
    resume!(output, rule; tadd=5)
    @test output[3] == test
    @test output[5] == test2
    replay(output)
end

@testset "REPLOutput{:braile} works" begin 
    output = REPLOutput{:braile}(init; fps=100, store=true)
    sim!(output, ruleinit; tstop=2)
    resume!(output, rule; tadd=3)
    @test output[3] == test
    @test output[5] == test2
    replay(output)
end
