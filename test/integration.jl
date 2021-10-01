using DynamicGrids, DimensionalData, Test, Dates, Unitful, 
      CUDAKernels, FileIO, FixedPointNumbers, Colors
using DynamicGrids: Extent, SimData, gridview

if CUDAKernels.CUDA.has_cuda_gpu()
    CUDAKernels.CUDA.allowscalar(false)
    hardware = (SingleCPU(), ThreadedCPU(), CPUGPU())
    # hardware = (CPUGPU(),) 
else
    hardware = (SingleCPU(), ThreadedCPU(), CPUGPU())
end
opts = (NoOpt(), SparseOpt())

proc = CPUGPU()
proc = SingleCPU()
opt = SparseOpt()
opt = NoOpt()

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
    init =  DimArray(Bool[
             0 0 0 0 0 0
             0 0 0 1 1 1
             0 0 0 0 0 1
             0 0 0 0 1 0
             0 0 0 0 0 0
            ], (Y, X)),
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

test = test5_6
proc = SingleCPU()
proc = CPUGPU()

@testset "Life simulation Wrap" begin
    # Test on two sizes to test half blocks on both axes
    # Loop over shifing init arrays to make sure they all work
    for test in (test5_6, test6_7), i in 1:size(test[:init], 1)
        for j in 1:size(test[:init], 2)
            for proc in hardware, opt in opts
                tspan = Date(2001, 1, 1):Day(2):Date(2001, 1, 14)
                ruleset = Ruleset(;
                    rules=(Life(),),
                    timestep=Day(2),
                    boundary=Wrap(),
                    proc=proc,
                    opt=opt,
                )
                @testset "$(nameof(typeof(proc))) $(nameof(typeof(opt))) results match glider behaviour" begin
                    rule = Life(neighborhood=Moore{1}())
                    output = ArrayOutput(test[:init], tspan=tspan)
                    sim!(output, ruleset)
                    @test output[2] == test[:test2] # || (println(2); display(output[2]); display(test[:test2]))
                    @test output[3] == test[:test3] # || (println(3); display(output[3]); display(test[:test3]))
                    @test output[4] == test[:test4] # || (println(4); display(output[4]); display(test[:test4]))
                    @test output[5] == test[:test5] # || (println(5); display(output[5]); display(test[:test5]))
                    @test output[7] == test[:test7] # || (println(7); display(output[7]); display(test[:test7]))
                end
                @testset "$(nameof(typeof(proc))) $(nameof(typeof(opt))) using step!" begin
                    simdata = DynamicGrids._proc_setup(SimData(Extent(; init=test[:init], tspan=tspan), ruleset))
                    # Need Array here to copy from GPU to CPU
                    @test Array(gridview(first(simdata))) == test[:init]
                    simdata = step!(simdata)
                    @test Array(gridview(first(simdata))) == test[:test2] # || (println("s2"); display(Array(gridview(first(simdata)))); display(test[:test2]))
                    simdata = step!(simdata)
                    @test Array(gridview(first(simdata))) == test[:test3] # || (println("s3"); display(Array(gridview(first(simdata)))); display(test[:test3]))
                    simdata = step!(simdata)
                    @test Array(gridview(first(simdata))) == test[:test4] # || (println("s4"); display(Array(gridview(first(simdata)))); display(test[:test4]))
                    simdata = step!(simdata)
                    @test Array(gridview(first(simdata))) == test[:test5] # || (println("s5"); display(Array(gridview(first(simdata)))); display(test[:test5]))
                    simdata = step!(simdata)
                    simdata = step!(simdata)
                    @test Array(gridview(first(simdata))) == test[:test7] # || (println("s7"); display(Array(gridview(first(simdata)))); display(test[:test7]))
                end
            end
            cyclej!(test)
        end
        cyclei!(test)
    end
    nothing
end

@testset "Life simulation with Remove boudary" begin
    init_ =     DimArray(Bool[
                 0 0 0 0 0 0 0
                 0 0 0 0 1 1 1
                 0 0 0 0 0 0 1
                 0 0 0 0 0 1 0
                 0 0 0 0 0 0 0
                 0 0 0 0 0 0 0
                ], (X, Y))
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

    @testset "Wrong timestep throws an error" begin
        rs = Ruleset(rule; timestep=Day(2), boundary=Remove(), opt=NoOpt())
        output = ArrayOutput((a=init_,); tspan=1:7)
        @test_throws ArgumentError sim!(output, rs; tspan=Date(2001, 1, 1):Month(1):Date(2001, 3, 1))
    end

    @testset "Results match glider behaviour" begin
        output = ArrayOutput((a=init_,); tspan=1:7)
        for proc in hardware, opt in opts
            sim!(output, rule; boundary=Remove(), proc=proc, opt=opt)
            @test output[2][:a] == test2_rem
            @test output[3][:a] == test3_rem
            @test output[4][:a] == test4_rem
            @test output[5][:a] == test5_rem
            @test output[7][:a] == test7_rem
        end
    end

    @testset "Combinatoric comparisons in a larger Life sim" begin
        rule = Life(neighborhood=Moore(1))
        init_ = rand(Bool, 100, 99)
        mask_ = ones(Bool, size(init_)...)
        mask_[1:50, 1:50] .= false  
        wrap_rs_ref = Ruleset(rule; boundary=Wrap())
        remove_rs_ref = Ruleset(rule; boundary=Remove())
        wrap_output_ref = ArrayOutput(init_; tspan=1:100, mask=mask_)
        remove_output_ref = ArrayOutput(init_; tspan=1:100, mask=mask_)
        sim!(remove_output_ref, remove_rs_ref)
        sim!(wrap_output_ref, wrap_rs_ref)
        for proc in hardware, opt in opts
            @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
                @testset "Wrap" begin
                    wrap_rs = Ruleset(rule; boundary=Wrap(), proc=proc, opt=opt)
                    wrap_output = ArrayOutput(init_; tspan=1:100, mask=mask_)
                    sim!(wrap_output, wrap_rs)
                    wrap_output_ref[2] .- wrap_output[2]
                    @test wrap_output_ref[2] == wrap_output[2]
                    wrap_output_ref[3] .- wrap_output[3]
                    @test wrap_output_ref[3] == wrap_output[3]
                    @test wrap_output_ref[10] == wrap_output[10]
                    @test wrap_output_ref[100] == wrap_output[100]
                end
                @testset "Remove" begin
                    remove_rs = Ruleset(rule; boundary=Remove(), proc=proc, opt=opt)
                    remove_output = ArrayOutput(init_; tspan=1:100, mask=mask_)
                    sim!(remove_output, remove_rs);
                    @test remove_output_ref[2] == remove_output[2]
                    @test remove_output_ref[3] == remove_output[3]
                    remove_output_ref[3] .- remove_output[3]
                    @test remove_output_ref[10] == remove_output[10]
                    @test remove_output_ref[100] == remove_output[100]
                end
            end
        end
    end

end

@testset "sim! with other outputs" begin
    for proc in hardware, opt in opts
        @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
            @testset "Transformed output" begin
                ruleset = Ruleset(Life();
                    timestep=Month(1),
                    boundary=Wrap(),
                    proc=proc,
                    opt=opt,
                )
                tspan_ = Date(2010, 4):Month(1):Date(2010, 7)
                output = TransformedOutput(sum, test6_7[:init]; tspan=tspan_)
                sim!(output, ruleset)
                @test output[1] == sum(test6_7[:init])
                @test output[2] == sum(test6_7[:test2])
                @test output[3] == sum(test6_7[:test3])
                @test output[4] == sum(test6_7[:test4])
            end
            @testset "REPLOutput block works, in Unitful.jl seconds" begin
                ruleset = Ruleset(;
                    rules=(Life(),),
                    timestep=5u"s",
                    boundary=Wrap(),
                    proc=proc,
                    opt=opt,
                )
                output = REPLOutput(test6_7[:init]; 
                    tspan=0u"s":5u"s":6u"s", style=Block(), fps=1000, store=true
                )
                @test DynamicGrids.isstored(output) == true
                sim!(output, ruleset)
                resume!(output, ruleset; tstop=30u"s")
                @test output[At(5u"s")] == test6_7[:test2]
                @test output[At(10u"s")] == test6_7[:test3]
                @test output[At(20u"s")] == test6_7[:test5]
                @test output[At(30u"s")] == test6_7[:test7]
            end
            @testset "REPLOutput braile works, in Months" begin
                ruleset = Ruleset(Life();
                    timestep=Month(1),
                    boundary=Wrap(),
                    proc=proc,
                    opt=opt,
                )
                tspan_ = Date(2010, 4):Month(1):Date(2010, 7)
                output = REPLOutput(test6_7[:init]; tspan=tspan_, style=Braile(), fps=1000, store=false)
                sim!(output, ruleset)
                @test output[At(Date(2010, 7))] == test6_7[:test4]
                @test DynamicGrids.tspan(output) == Date(2010, 4):Month(1):Date(2010, 7)
                resume!(output, ruleset; tstop=Date(2010, 10))
                @test DynamicGrids.tspan(output) == Date(2010, 4):Month(1):Date(2010, 10)
                @test output[1] == test6_7[:test7]
            end
        end
    end
end

@testset "GifOutput saves" begin
    @testset "Image generator" begin
        # TODO fix on CUDA: cell_to_rgb indexes a CuArray
        ruleset = Ruleset(;
            rules=(Life(),),
            boundary=Wrap(),
            timestep=5u"s",
            opt=NoOpt(),
        )
        output = GifOutput(test6_7[:init]; 
            filename="test_gifoutput.gif", text=nothing,
            tspan=0u"s":5u"s":30u"s", fps=10, store=true,
        )
        @test output.imageconfig.renderer isa Image
        @test output.imageconfig.textconfig == nothing
        @test DynamicGrids.isstored(output) == true
        sim!(output, ruleset)
        @test output[At(5u"s")] == test6_7[:test2]
        @test output[At(10u"s")] == test6_7[:test3]
        @test output[At(20u"s")] == test6_7[:test5]
        @test output[At(30u"s")] == test6_7[:test7]
        gif = load("test_gifoutput.gif")
        @test gif == RGB.(output.gif)
        rm("test_gifoutput.gif")
    end
    @testset "Layout" begin
        # TODO fix on CUDA
        zeroed = test6_7[:init]
        ruleset = Ruleset(Life{:a}(); boundary=Wrap())
        output = GifOutput((a=test6_7[:init], b=zeroed); 
            filename="test_gifoutput2.gif", text=nothing,               
            tspan=0u"s":5u"s":30u"s", fps=10, store=true
        )
        @test DynamicGrids.isstored(output) == true
        @test output.imageconfig.renderer isa Layout
        @test output.imageconfig.textconfig == nothing
        sim!(output, ruleset)
        @test all(map(==, output[At(5u"s")], (a=test6_7[:test2], b=zeroed)))
        @test all(map(==, output[At(10u"s")], (a=test6_7[:test3], b=zeroed)))
        @test all(map(==, output[At(20u"s")], (a=test6_7[:test5], b=zeroed)))
        @test all(map(==, output[At(30u"s")], (a=test6_7[:test7], b=zeroed)))
        gif = load("test_gifoutput2.gif")
        @test gif == RGB.(output.gif)
        @test gif[:, 1, 7] == RGB{N0f8}.([1.0, 1.0, 0.298, 0.298, 0.298, 1.0])
        rm("test_gifoutput2.gif")
    end
end

@testset "SparseOpt rules run everywhere with non zero values" begin
    set_hood = SetNeighbors() do data, hood, val, I 
        for p in positions(hood, I)
            data[p...] = 2
        end
    end
    clearcell = Cell() do data, val, I
        zero(val)
    end
    output = ArrayOutput(ones(10, 11); tspan=1:3)
    sim!(output, set_hood; opt=SparseOpt())
    @test all(output[3] .=== 2.0)
    sim!(output, set_hood, clearcell; opt=SparseOpt())
    @test all(output[3] .=== 0.0)
end
