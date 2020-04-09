using DynamicGrids, Test, Dates, Unitful

# life glider sims

init =  [
         0 0 0 0 0 0 0
         0 0 0 0 1 1 1
         0 0 0 0 0 0 1
         0 0 0 0 0 1 0
         0 0 0 0 0 0 0
         0 0 0 0 0 0 0
        ]

test2 = [
         0 0 0 0 0 1 0
         0 0 0 0 0 1 1
         0 0 0 0 1 0 1
         0 0 0 0 0 0 0
         0 0 0 0 0 0 0
         0 0 0 0 0 0 0
        ]

test3 = [
         0 0 0 0 0 1 1
         0 0 0 0 1 0 1
         0 0 0 0 0 0 1
         0 0 0 0 0 0 0
         0 0 0 0 0 0 0
         0 0 0 0 0 0 0
        ]

test5 = [
         1 0 0 0 0 1 1
         1 0 0 0 0 0 0
         0 0 0 0 0 0 1
         0 0 0 0 0 0 0
         0 0 0 0 0 0 0
         0 0 0 0 0 0 0
        ]

test7 = [
         1 0 0 0 0 1 0
         1 0 0 0 0 0 0
         0 0 0 0 0 0 0
         0 0 0 0 0 0 0
         0 0 0 0 0 0 0
         1 0 0 0 0 0 1
        ]

# Allow testing with a few variants of the above
cycle!(A) = begin
    v = A[1, :]
    @inbounds copyto!(A, CartesianIndices((1:5, 1:7)),
                      A, CartesianIndices((2:6, 1:7)))
    A[6, :] = v
end



@testset "RemoveOverflow works" begin
    test2_rem = [
                 0 0 0 0 0 1 0
                 0 0 0 0 0 1 1
                 0 0 0 0 1 0 1
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]

    test3_rem = [
                 0 0 0 0 0 1 1
                 0 0 0 0 1 0 1
                 0 0 0 0 0 0 1
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]

    test5_rem = [
                 0 0 0 0 0 1 1
                 0 0 0 0 0 0 1
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]

    test7_rem = [
                 0 0 0 0 0 1 1
                 0 0 0 0 0 1 1
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]

    ruleset = Ruleset(; 
        rules=(Life(),), 
        init=init, 
        timestep=Day(2), 
        overflow=RemoveOverflow(),
        opt=NoOpt(),
    )
    output = ArrayOutput(init, 7)
    sim!(output, ruleset; tspan=(Date(2001, 1, 1), Date(2001, 1, 14)))

    @testset "NoOpt results match glider behaviour" begin
        @test output[2] == test2_rem
        @test output[3] == test3_rem
        @test output[5] == test5_rem
        @test output[7] == test7_rem
    end
end


@testset "WrapOverflow works" begin
    for i = 1:7 
        sparse_ruleset = Ruleset(; 
            rules=(Life(),), 
            init=init, 
            timestep=Day(2), 
            overflow=WrapOverflow(),
            opt=SparseOpt(),
        )
        sparse_output = ArrayOutput(init, 7)
        sim!(sparse_output, sparse_ruleset; tspan=(Date(2001, 1, 1), Date(2001, 1, 14)))

        @testset "SparseOpt results match glider behaviour" begin
            @test sparse_output[2] == test2
            @test sparse_output[3] == test3
            @test sparse_output[5] == test5
            @test sparse_output[7] == test7
        end

        noopt_ruleset = Ruleset(; 
            rules=(Life(),), 
            init=init, 
            timestep=Day(2), 
            overflow=WrapOverflow(),
            opt=NoOpt(),
        )
        noopt_output = ArrayOutput(init, 7)
        sim!(noopt_output, noopt_ruleset; tspan=(Date(2001, 1, 1), Date(2001, 1, 14)))

        @testset "NoOpt results match glider behaviour" begin
            @test noopt_output[2] == test2
            @test noopt_output[3] == test3
            @test noopt_output[5] == test5
            @test noopt_output[7] == test7
        end
        cycle!(init)
        cycle!(test2)
        cycle!(test3)
        cycle!(test5)
        cycle!(test7)
    end
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
    resume!(output, ruleset; tstop=30u"s")
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
    @test output[7] == test7
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
    resume!(output, ruleset; tstop=Date(2010, 11))
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
    @test output[7] == test7
end

