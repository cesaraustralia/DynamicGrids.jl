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
cycletests!(A) = begin
    v = A[1, :]
    @inbounds copyto!(A, CartesianIndices((1:5, 1:7)),
                      A, CartesianIndices((2:6, 1:7)))
    A[6, :] = v
end

@testset "Life simulation with RemoveOverflow and replicates" begin
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

    rule = Life{:a,:a}(neighborhood=RadialNeighborhood{1}())
    ruleset = Ruleset(rule; 
        timestep=Day(2), 
        overflow=RemoveOverflow(),
        opt=NoOpt(),
    )

    @testset "Wrong timestep throws an error" begin
        output = ArrayOutput(init; tspan=1:7)
        @test_throws ArgumentError sim!(output, ruleset; tspan=Date(2001, 1, 1):Month(1):Date(2001, 3, 1))
    end

    @testset "Results match glider behaviour" begin
        output = ArrayOutput((a=init,); tspan=(Date(2001, 1, 1):Day(2):Date(2001, 1, 14)))
        sim!(output, rule; overflow=RemoveOverflow(), nreplicates=5)
        @test output[2][:a] == test2_rem
        @test output[3][:a] == test3_rem
        @test output[5][:a] == test5_rem
        @test output[7][:a] == test7_rem
    end

end


@testset "Life simulation with WrapOverflow" begin
    # Loop over shifing init to make sure they all work
    for i = 1:7 
        bufs = (zeros(Int, 3, 3), zeros(Int, 3, 3))
        rule = Life(neighborhood=RadialNeighborhood{1}(bufs))
        sparse_ruleset = Ruleset(; 
            rules=(rule,), 
            timestep=Day(2), 
            overflow=WrapOverflow(),
            opt=SparseOpt(),
        )
        sparse_output = ArrayOutput(init; tspan=Date(2001, 1, 1):Day(2):Date(2001, 1, 14))
        sim!(sparse_output, sparse_ruleset)

        @testset "SparseOpt results match glider behaviour" begin
            @test sparse_output[2] == test2
            @test sparse_output[3] == test3
            @test sparse_output[5] == test5
            @test sparse_output[7] == test7
        end

        noopt_ruleset = Ruleset(; 
            rules=(Life(),), 
            timestep=Day(2), 
            overflow=WrapOverflow(),
            opt=NoOpt(),
        )
        noopt_output = ArrayOutput(init, tspan=Date(2001, 1, 1):Day(2):Date(2001, 1, 14))
        sim!(noopt_output, noopt_ruleset) 

        @testset "NoOpt results match glider behaviour" begin
            @test noopt_output[2] == test2
            @test noopt_output[3] == test3
            @test noopt_output[5] == test5
            @test noopt_output[7] == test7
        end
        cycletests!(init)
        cycletests!(test2)
        cycletests!(test3)
        cycletests!(test5)
        cycletests!(test7)
    end
end


@testset "REPLOutput block works, in Unitful.jl seconds" begin
    ruleset = Ruleset(; 
        rules=(Life(),), 
        overflow=WrapOverflow(),
        timestep=5u"s",
        opt=NoOpt(),
    )
    tspan=0u"s":5u"s":6u"s"
    output = REPLOutput(init; tspan=tspan, style=Block(), fps=100, store=true)
    DynamicGrids.isstored(output)
    DynamicGrids.store(output)
    sim!(output, ruleset)
    resume!(output, ruleset; tstop=30u"s")
    @test output[2] == test2
    @test output[3] == test3
    @test output[5] == test5
    @test output[7] == test7
end

@testset "REPLOutput braile works, in Months" begin
    init_a = (_default_=init,)
    ruleset = Ruleset(Life(); 
        overflow=WrapOverflow(),
        timestep=Month(1),
        opt=SparseOpt(),
    )
    tspan = Date(2010, 4):Month(1):Date(2010, 7)
    output = REPLOutput(init_a; tspan=tspan, style=Braile(), fps=100, store=true)
    sim!(output, ruleset)
    @test output[2][:_default_] == test2
    @test output[3][:_default_] == test3
    @test DynamicGrids.tspan(output) == Date(2010, 4):Month(1):Date(2010, 7)
    resume!(output, ruleset; tstop=Date(2010, 11))
    @test DynamicGrids.tspan(output) == Date(2010, 4):Month(1):Date(2010, 11)
    @test output[5][:_default_] == test5
    @test output[7][:_default_] == test7
end
