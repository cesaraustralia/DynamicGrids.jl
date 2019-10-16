using DynamicGrids, Test, Dates, Unitful

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

ruleset = Ruleset(Life(); init=init, overflow=WrapOverflow(), timestep=Day(2))
output = ArrayOutput(init, 5)
sim!(output, ruleset; tspan=(Date(2001, 1, 1), Date(2001, 1, 10)))

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


@testset "REPLOutput block works, in Unitful.jl seconds" begin
    ruleset = Ruleset(Life(); init=init, overflow=WrapOverflow(), timestep=5u"s")
    output = REPLOutput(init; style=Block(), fps=100, store=true)
    sim!(output, ruleset; tspan=(0u"s", 10u"s"))
    resume!(output, ruleset; tstop=25u"s")
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
    # replay(output, ruleset)
end

@testset "REPLOutput braile works, in Months" begin
    ruleset = Ruleset(Life(); init=init, overflow=WrapOverflow(), timestep=Month(1))
    output = REPLOutput(init; style=Braile(), fps=100, store=true)
    sim!(output, ruleset; tspan=(Date(2010, 4), Date(2010, 7)))
    resume!(output, ruleset; tstop=Date(2010, 9))
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
    # replay(output, ruleset)
end
