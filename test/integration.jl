using DynamicGrids, Test, Dates, Unitful

# life glider sims

# Test all cycled variants of the array
cyclei!(arrays) = begin
    for A in arrays
        v = A[1, :]
        @inbounds copyto!(A, CartesianIndices((1:size(A, 1)-1, 1:size(A, 2))),
                          A, CartesianIndices((2:size(A, 1), 1:size(A, 2))))
        A[end, :] = v
    end
end

cyclej!(arrays) = begin
    for A in arrays
        v = A[:, 1]
        @inbounds copyto!(A, CartesianIndices((1:size(A, 1), 1:size(A, 2)-1)),
                          A, CartesianIndices((1:size(A, 1), 2:size(A, 2))))
        A[:, end] = v
    end
end

test6_7 = (
    init =  Bool[
             0 0 0 0 0 0 0
             0 0 0 0 1 1 1
             0 0 0 0 0 0 1
             0 0 0 0 0 1 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
            ],
    test2 = Bool[
             0 0 0 0 0 1 0
             0 0 0 0 0 1 1
             0 0 0 0 1 0 1
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
            ],
    test3 = Bool[
             0 0 0 0 0 1 1
             0 0 0 0 1 0 1
             0 0 0 0 0 0 1
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
            ],
    test4 = Bool[
             0 0 0 0 0 1 1
             1 0 0 0 0 0 1
             0 0 0 0 0 1 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
            ],
    test5 = Bool[
             1 0 0 0 0 1 1
             1 0 0 0 0 0 0
             0 0 0 0 0 0 1
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
            ],
    test7 = Bool[
             1 0 0 0 0 1 0
             1 0 0 0 0 0 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
             1 0 0 0 0 0 1
            ]
)

test5_6 = (
    init =  Bool[
             0 0 0 0 0 0
             0 0 0 1 1 1
             0 0 0 0 0 1
             0 0 0 0 1 0
             0 0 0 0 0 0
            ],
    test2 = Bool[
             0 0 0 0 1 0
             0 0 0 0 1 1
             0 0 0 1 0 1
             0 0 0 0 0 0
             0 0 0 0 0 0
            ],
    test3 = Bool[
             0 0 0 0 1 1
             0 0 0 1 0 1
             0 0 0 0 0 1
             0 0 0 0 0 0
             0 0 0 0 0 0
            ],
    test4 = Bool[
             0 0 0 0 1 1
             1 0 0 0 0 1
             0 0 0 0 1 0
             0 0 0 0 0 0
             0 0 0 0 0 0
            ],
    test5 = Bool[
             1 0 0 0 1 1
             1 0 0 0 0 0
             0 0 0 0 0 1
             0 0 0 0 0 0
             0 0 0 0 0 0
            ],
    test7 = Bool[
             1 0 0 0 1 0
             1 0 0 0 0 0
             0 0 0 0 0 0
             0 0 0 0 0 0
             1 0 0 0 0 1
            ]
)


@testset "Life simulation with WrapOverflow" begin
    # Test on two sizes to test half blocks on both axes
    for test in (test5_6, test6_7)
        # Loop over shifing init arrays to make sure they all work
        for i = 1:size(test[:init], 1)
            for j = 1:size(test[:init], 2)
                bufs = (zeros(Int, 3, 3), zeros(Int, 3, 3))
                rule = Life(neighborhood=Moore{1}(bufs))
                sparse_ruleset = Ruleset(;
                    rules=(rule,),
                    timestep=Day(2),
                    overflow=WrapOverflow(),
                    opt=SparseOpt(),
                )
                noopt_ruleset = Ruleset(;
                    rules=(Life(),),
                    timestep=Day(2),
                    overflow=WrapOverflow(),
                    opt=NoOpt(),
                )
                sparse_output = ArrayOutput(test[:init]; tspan=Date(2001, 1, 1):Day(2):Date(2001, 1, 14))
                noopt_output = ArrayOutput(test[:init], tspan=Date(2001, 1, 1):Day(2):Date(2001, 1, 14))
                sim!(sparse_output, sparse_ruleset)
                sim!(noopt_output, noopt_ruleset)

                @testset "SparseOpt results match glider behaviour" begin
                    @test sparse_output[2] == test[:test2]
                    @test sparse_output[3] == test[:test3]
                    @test sparse_output[4] == test[:test4]
                    @test sparse_output[5] == test[:test5]
                    @test sparse_output[7] == test[:test7]
                end
                @testset "NoOpt results match glider behaviour" begin
                    @test noopt_output[2] == test[:test2]
                    @test noopt_output[3] == test[:test3]
                    @test noopt_output[4] == test[:test4]
                    @test noopt_output[5] == test[:test5]
                    @test noopt_output[7] == test[:test7]
                end

                cyclej!(test)
            end
            cyclei!(test)
        end
    end
end

@testset "Life simulation with RemoveOverflow and replicates" begin
    init_ =     Bool[
                 0 0 0 0 0 0 0
                 0 0 0 0 1 1 1
                 0 0 0 0 0 0 1
                 0 0 0 0 0 1 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]
    test2_rem = Bool[
                 0 0 0 0 0 1 0
                 0 0 0 0 0 1 1
                 0 0 0 0 1 0 1
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]
    test3_rem = Bool[
                 0 0 0 0 0 1 1
                 0 0 0 0 1 0 1
                 0 0 0 0 0 0 1
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]
    test4_rem = Bool[
                 0 0 0 0 0 1 1
                 0 0 0 0 0 0 1
                 0 0 0 0 0 1 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]
    test5_rem = Bool[
                 0 0 0 0 0 1 1
                 0 0 0 0 0 0 1
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]
    test7_rem = Bool[
                 0 0 0 0 0 1 1
                 0 0 0 0 0 1 1
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ]

    rule = Life{:a,:a}(neighborhood=Moore(1))
    rs = Ruleset(rule;
        timestep=Day(2),
        overflow=RemoveOverflow(),
        opt=NoOpt(),
    )

    @testset "Wrong timestep throws an error" begin
        output = ArrayOutput(init_; tspan=1:7)
        @test_throws ArgumentError sim!(output, rs; tspan=Date(2001, 1, 1):Month(1):Date(2001, 3, 1))
    end

    @testset "Results match glider behaviour" begin
        output = ArrayOutput((a=init_,); tspan=(Date(2001, 1, 1):Day(2):Date(2001, 1, 14)))
        @testset "NoOpt" begin
            sim!(output, rule; overflow=RemoveOverflow(), opt=NoOpt())
            @test output[2][:a] == test2_rem
            @test output[3][:a] == test3_rem
            @test output[4][:a] == test4_rem
            @test output[5][:a] == test5_rem
            @test output[7][:a] == test7_rem
        end
        @testset "SparseOpt" begin
            sim!(output, rule; overflow=RemoveOverflow(), opt=SparseOpt())
            @test output[2][:a] == test2_rem
            @test output[3][:a] == test3_rem
            @test output[4][:a] == test4_rem
            @test output[5][:a] == test5_rem
            @test output[7][:a] == test7_rem
        end
    end

    @testset "A large sim wors" begin
        init = rand(Bool, 100, 100)
        rule = Life(neighborhood=Moore(1))
        sparse_opt = Ruleset(rule;
            overflow=WrapOverflow(),
            opt=SparseOpt(),
        )
        no_opt = Ruleset(rule;
            overflow=WrapOverflow(),
            opt=NoOpt(),
        )
        sparseopt_output = ArrayOutput(init; tspan=1:100)
        sim!(sparseopt_output, sparse_opt)
        noopt_output = ArrayOutput(init; tspan=1:100)
        sim!(noopt_output, no_opt)
        @test sparseopt_output[2] == noopt_output[2]
        @test sparseopt_output[3] == noopt_output[3]
        @test sparseopt_output[10] == noopt_output[10]
        @test sparseopt_output[100] == noopt_output[100]

        init = rand(Bool, 100, 100)
        rule = Life(neighborhood=Moore(1))
        sparse_opt = Ruleset(rule;
            overflow=RemoveOverflow(),
            opt=SparseOpt(),
        )
        no_opt = Ruleset(rule;
            overflow=RemoveOverflow(),
            opt=NoOpt(),
        )
        sparseopt_output = ArrayOutput(init; tspan=1:100)
        sim!(sparseopt_output, sparse_opt)
        noopt_output = ArrayOutput(init; tspan=1:100)
        sim!(noopt_output, no_opt)
        @test sparseopt_output[2] == noopt_output[2]
        @test sparseopt_output[3] == noopt_output[3]
        @test sparseopt_output[10] == noopt_output[10]
        @test sparseopt_output[100] == noopt_output[100]
    end
end

@testset "ResultOutput works" begin
    ruleset = Ruleset(;
        rules=(Life(),),
        overflow=WrapOverflow(),
        timestep=5u"s",
        opt=NoOpt(),
    )
    tspan=0u"s":5u"s":30u"s"
    output = ResultOutput(test6_7[:init]; tspan=tspan)
    sim!(output, ruleset)
    @test output[1] == test6_7[:test7]
end

@testset "REPLOutput block works, in Unitful.jl seconds" begin
    ruleset = Ruleset(;
        rules=(Life(),),
        overflow=WrapOverflow(),
        timestep=5u"s",
        opt=NoOpt(),
    )
    tspan=0u"s":5u"s":6u"s"
    output = REPLOutput(test6_7[:init]; tspan=tspan, style=Block(), fps=100, store=true)
    @test DynamicGrids.isstored(output) == true
    sim!(output, ruleset)
    resume!(output, ruleset; tstop=30u"s")
    @test output[2] == test6_7[:test2]
    @test output[3] == test6_7[:test3]
    @test output[5] == test6_7[:test5]
    @test output[7] == test6_7[:test7]
end

@testset "REPLOutput braile works, in Months" begin
    init_a = (_default_=test6_7[:init],)
    ruleset = Ruleset(Life();
        overflow=WrapOverflow(),
        timestep=Month(1),
        opt=SparseOpt(),
    )
    tspan = Date(2010, 4):Month(1):Date(2010, 7)
    output = REPLOutput(init_a; tspan=tspan, style=Braile(), fps=100, store=false)

    sim!(output, ruleset)
    @test output[1][:_default_] == test6_7[:test4]
    @test DynamicGrids.tspan(output) == Date(2010, 4):Month(1):Date(2010, 7)

    resume!(output, ruleset; tstop=Date(2010, 10))
    @test DynamicGrids.tspan(output) == Date(2010, 4):Month(1):Date(2010, 10)
    @test output[1][:_default_] == test6_7[:test7]

end

