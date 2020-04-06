using DynamicGrids, Test, Dates, Unitful

# life glider sims

init =  [0 0 0 0 0 0 0;
         0 0 0 0 0 0 0;
         0 0 0 0 0 0 0;
         0 0 0 0 1 1 1;
         0 0 0 0 0 0 1;
         0 0 0 0 0 1 0]

test2 = [0 0 0 0 0 0 0;
         0 0 0 0 0 0 0;
         0 0 0 0 0 1 0;
         0 0 0 0 0 1 1;
         0 0 0 0 1 0 1;
         0 0 0 0 0 0 0]

test3 = [0 0 0 0 0 0 0;
         0 0 0 0 0 0 0;
         0 0 0 0 0 1 1;
         0 0 0 0 1 0 1;
         0 0 0 0 0 0 1;
         0 0 0 0 0 0 0]

test5 = [0 0 0 0 0 0 0;
         0 0 0 0 0 0 0;
         1 0 0 0 0 1 1;
         1 0 0 0 0 0 0;
         0 0 0 0 0 0 1;
         0 0 0 0 0 0 0]

test7 = [0 0 0 0 0 0 0;
         1 0 0 0 0 0 1;
         1 0 0 0 0 1 0;
         1 0 0 0 0 0 0;
         0 0 0 0 0 0 0;
         0 0 0 0 0 0 0]


sparse_ruleset = Ruleset(; 
    rules=(Life(),), 
    init=init, 
    timestep=Day(2), 
    overflow=WrapOverflow(),
    opt=SparseOpt(),
)
sparse_output = ArrayOutput(init, 7)
sim!(sparse_output, sparse_ruleset; tspan=(Date(2001, 1, 1), Date(2001, 1, 14)))

noopt_ruleset = Ruleset(; 
    rules=(Life(),), 
    init=init, 
    timestep=Day(2), 
    overflow=WrapOverflow(),
    opt=NoOpt(),
)
noopt_output = ArrayOutput(init, 7)
sim!(noopt_output, noopt_ruleset; tspan=(Date(2001, 1, 1), Date(2001, 1, 14)))

noopt_output[1]
noopt_output[2]
noopt_output[3]
noopt_output[5]
noopt_output[6]
noopt_output[7]

@testset "stored results match glider behaviour" begin
    @test noopt_output[2] == sparse_output[2] == test2
    @test noopt_output[3] == sparse_output[3] == test3
    @test noopt_output[5] == sparse_output[5] == test5
    @test noopt_output[7] == sparse_output[7] == test7
end

@testset "REPLOutput block works, in Unitful.jl seconds" begin
    ruleset = Ruleset(; 
        rules=(Life(),), 
        init=init, 
        overflow=WrapOverflow(),
        timestep=5u"s",
        opt=NoOpt(),
    )
    output = REPLOutput(init; style=Block(), fps=100, store=true)
    sim!(output, ruleset; tspan=(0u"s", 6u"s"))
    resume!(output, ruleset; tstop=20u"s")

    output[1]
    output[2]
    output[3]
    output[5]
    output[6]
    output[7]
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
end

@testset "REPLOutput braile works, in Months" begin
    ruleset = Ruleset(; 
        rules=(Life(),), 
        init=init, 
        overflow=WrapOverflow(),
        timestep=Month(1),
        opt=SparseOpt(),
    )
    output = REPLOutput(init; style=Braile(), fps=100, store=true)
    sim!(output, ruleset; tspan=(Date(2010, 4), Date(2010, 7)))
    resume!(output, ruleset; tstop=Date(2010, 9))
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
end
