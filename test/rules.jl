using DynamicGrids, ModelParameters, Setfield, Test, StaticArrays, 
      LinearAlgebra, CUDAKernels
import DynamicGrids: applyrule, applyrule!, maprule!, ruletype, extent, source, dest,
       _getreadgrids, _getwritegrids, _combinegrids, _readkeys, _writekeys,
       SimData, WritableGridData, Rule, Extent, CPUGPU

if CUDAKernels.CUDA.has_cuda_gpu()
    CUDAKernels.CUDA.allowscalar(false)
    # hardware = (SingleCPU(), ThreadedCPU(), CPUGPU(), CuGPU())
    hardware = (SingleCPU(), ThreadedCPU(), CPUGPU())
else
    hardware = (SingleCPU(), ThreadedCPU(), CPUGPU())
end

init  = [0 1 1 0
         0 1 1 0
         0 1 1 0
         0 1 1 0
         0 1 1 0]

proc = SingleCPU()
opt = NoOpt()

@testset "Generic rule constructors" begin
   rule1 = Cell{:a}(identity)
   @test rule1.f == identity
   @test_throws ArgumentError Cell()
   rule2 = Cell{:a,:a}(identity)
   @test rule1 == rule2
   #@test_throws ArgumentError Cell(identity, identity)
   rule1 = Neighbors{:a,:b}(identity, Moore(1))
   @test rule1.f == identity
   rule2 = Neighbors{:a,:b}(identity; neighborhood=Moore(1))
   @test rule1 == rule2
   @test typeof(rule1)  == Neighbors{:a,:b,typeof(identity),Moore{1,8,Nothing}}
   rule1 = Neighbors(identity, Moore(1))
   @test rule1.f == identity
   rule2 = Neighbors(identity; neighborhood=Moore(1))
   @test typeof(rule1)  == Neighbors{:_default_,:_default_,typeof(identity),Moore{1,8,Nothing}}
   @test rule1 == rule2
   @test_throws ArgumentError Neighbors()
   # @test_throws ArgumentError Neighbors(identity, identity, identity)
   rule1 = SetNeighbors{:a,:b}(identity, Moore(1))
   @test rule1.f == identity
   rule2 = SetNeighbors{:a,:b}(identity; neighborhood=Moore(1))
   @test rule1 == rule2
   @test typeof(rule1)  == SetNeighbors{:a,:b,typeof(identity),Moore{1,8,Nothing}}
   rule1 = SetNeighbors(identity, Moore(1))
   @test rule1.f == identity
   rule2 = SetNeighbors(identity; neighborhood=Moore(1))
   @test typeof(rule1)  == SetNeighbors{:_default_,:_default_,typeof(identity),Moore{1,8,Nothing}}
   @test rule1 == rule2
   @test_throws ArgumentError Neighbors()
   # @test_throws ArgumentError Neighbors(identity, identity, identity)
   rule1 = SetCell{:a,:b}(identity)
   @test rule1.f == identity
   @test_throws ArgumentError SetCell()
   # @test_throws ArgumentError SetCell(identity, identity)
end


@testset "Rulesets" begin
    rule1 = Cell(x -> 2x)
    rule2 = Cell(x -> 3x)
    rs1 = Ruleset((rule1, rule2); opt=NoOpt()) 
    rs2 = Ruleset(rule1, rule2; opt=NoOpt())
    @test rules(rs1) == rules(rs2)
    @test typeof(Ruleset(StaticRuleset(rs1))) == typeof(rs1)
    for fn in fieldnames(typeof(rs1))
        @test getfield(Ruleset(StaticRuleset(rs1)), fn) == getfield(rs1, fn)
    end
    @test typeof(Ruleset(StaticRuleset(rs1))) == typeof(rs1)
    ModelParameters.setparent!(rs2, (rule1,))
    @test rs2.rules == (rule1,)
end

@testset "Cell" begin
    rule = Cell((d, x, I) -> 2x)
    @test applyrule(nothing, rule, 1, (0, 0)) == 2
end

@testset "Neighbors" begin
    buf = [1 0 0; 0 0 1; 0 0 1]
    rule = Neighbors(VonNeumann(1, buf)) do data, hood, state, I
        sum(hood)
    end
    @test applyrule(nothing, rule, 0, (3, 3)) == 1
    rule = Neighbors(Moore{1}(buf)) do data, hood, state, I
        sum(hood)
    end
    @test applyrule(nothing, rule, 0, (3, 3)) == 3
    @test DynamicGrids._buffer(rule) === buf
end

@testset "Convolution" begin
    k = SA[1 0 1; 0 0 0; 1 0 1]
    @test Convolution{:a}(k) == Convolution{:a,:a}(; neighborhood=Kernel(Window(1), k)) 
    buf = SA[1 0 0; 0 0 1; 0 0 1]
    hood = Window{1,9,typeof(buf)}(buf)
    rule = Convolution{:a,:a}(; neighborhood=Kernel(hood, k))
    @test DynamicGrids.kernel(rule) === k 
    @test applyrule(nothing, rule, 0, (3, 3)) == k ⋅ buf
    output = ArrayOutput((a=init,); tspan=1:2)
    sim!(output, rule)
end

@testset "SetNeighbors" begin
    init  = [0 1 0 0
             0 0 0 0
             0 0 0 0
             0 1 0 0
             0 0 1 0]
    @test_throws ArgumentError SetNeighbors()
    @testset "atomics" begin
        rule = SetNeighbors(VonNeumann(1)) do data, hood, state, I
            if state > 0
                for pos in positions(hood, I)
                    add!(data, 1, pos...) 
                end
            end
        end
        output = ArrayOutput(init; tspan=1:2)
        for proc in hardware, opt in (NoOpt(), SparseOpt())
            @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
                ref_output = [1 1 1 0
                              0 1 0 0
                              0 1 0 0
                              1 1 2 0
                              0 2 1 1]
                sim!(output, rule, proc=proc, opt=opt)
                @test output[2] == ref_output
            end
        end
    end

    @testset "setindex" begin
        rule = SetNeighbors(VonNeumann(1)) do data, hood, state, I
            state == 0 && return nothing
            for pos in positions(hood, I)
                data[pos...] = 1 
            end
        end
        output = ArrayOutput(init; tspan=1:2)
        for proc in hardware, opt in (NoOpt(), SparseOpt())
            @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
                ref_output = [1 1 1 0
                              0 1 0 0
                              0 1 0 0
                              1 1 1 0
                              0 1 1 1]
                sim!(output, rule, proc=proc, opt=opt)
                @test output[2] == ref_output
            end
        end
    end

end

@testset "SetCell" begin
    init  = [0 1 0 0
             0 0 0 0
             0 0 0 0
             0 1 0 0
             0 0 1 0]
    @testset "add!" begin
        output = ArrayOutput(init; tspan=1:2)
        rule = SetCell() do data, state, I
            if state > 0
                pos = I[1] - 2, I[2]
                isinbounds(data, pos) && add!(first(data), 1, pos...)
            end
        end
        for proc in hardware, opt in (NoOpt(), SparseOpt())
            @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
                sim!(output, rule; proc=proc, opt=opt)
                ref_out = [0 1 0 0
                           0 1 0 0
                           0 0 1 0
                           0 1 0 0
                           0 0 1 0]
                @test output[2] == ref_out
            end
        end
    end
    @testset "setindex!" begin
        output = ArrayOutput(init; tspan=1:2)
        rule = SetCell() do data, state, I
            if state > 0
                pos = I[1] - 2, I[2]
                isinbounds(data, pos) && (data[pos...] = 5)
            end
        end
        sim!(output, rule)
        @test output[2] == [0 1 0 0
                            0 5 0 0
                            0 0 5 0
                            0 1 0 0
                            0 0 1 0]
    end
end

@testset "SetGrid" begin
    @test_throws ArgumentError SetGrid()
    rule = SetGrid() do r, w
        w .*= 2
    end
    init  = [0 1 0 0
             0 0 0 0
             0 0 0 0
             0 1 0 0
             0 0 1 0]
    output = ArrayOutput(init; tspan=1:2)
    for proc in hardware, opt in (NoOpt(), SparseOpt())
        @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
            sim!(output, rule; proc=proc, opt=opt)
            @test output[2] == [0 2 0 0
                                0 0 0 0
                                0 0 0 0
                                0 2 0 0
                                0 0 2 0]
        end
    end
end

struct AddOneRule{R,W} <: CellRule{R,W} end
DynamicGrids.applyrule(data, ::AddOneRule, state, args...) = state + 1


@testset "Rulset mask ignores false cells" begin
    init = [0.0 4.0 0.0
            0.0 5.0 8.0
            3.0 6.0 0.0]
    mask = Bool[0 1 0
                0 1 1
                1 1 0]
    ruleset1 = Ruleset(AddOneRule{:_default_,:_default_}(); opt=NoOpt())
    ruleset2 = Ruleset(AddOneRule{:_default_,:_default_}(); opt=SparseOpt())
    output1 = ArrayOutput(init; tspan=1:3, mask=mask)
    output2 = ArrayOutput(init; tspan=1:3, mask=mask)
    sim!(output1, ruleset1)
    sim!(output2, ruleset2)
    @test output1[1] == output2[1] == [0.0 4.0 0.0
                                       0.0 5.0 8.0
                                       3.0 6.0 0.0]
    @test output1[2] == output2[2] == [0.0 5.0 0.0
                                       0.0 6.0 9.0
                                       4.0 7.0 0.0]
    @test output1[3] == output2[3] == [0.0 6.0 0.0
                                       0.0 7.0 10.0
                                       5.0 8.0 0.0]
end

# Single grid rules

struct TestRule{R,W} <: CellRule{R,W} end
applyrule(data, ::TestRule, state, index) = 0

@testset "A rule that returns zero gives zero outputs" begin
    final = [0 0 0 0
             0 0 0 0
             0 0 0 0
             0 0 0 0
             0 0 0 0]
    mask = nothing
    rule = TestRule{:a,:a}()

    for proc in (SingleCPU(), ThreadedCPU()), opt in (NoOpt(), SparseOpt())
        @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
            ruleset = Ruleset(rule; opt=opt, proc=proc)
            @test DynamicGrids.boundary(ruleset) === Remove()
            @test DynamicGrids.opt(ruleset) === opt
            @test DynamicGrids.proc(ruleset) === proc
            @test DynamicGrids.cellsize(ruleset) === 1
            @test DynamicGrids.timestep(ruleset) === nothing
            @test DynamicGrids.ruleset(ruleset) === ruleset

            ext = Extent(; init=(a=init,), tspan=1:1)
            simdata = SimData(ext, ruleset)

            # Test maprules components
            rkeys, rgrids = _getreadgrids(rule, simdata)
            wkeys, wgrids = _getwritegrids(rule, simdata)
            @test rkeys == Val{:a}()
            @test wkeys == Val{:a}()
            newsimdata = @set simdata.grids = _combinegrids(rkeys, rgrids, wkeys, wgrids)
            @test newsimdata.grids[1] isa WritableGridData
            # Test type stability
            T = Val{DynamicGrids.ruletype(rule)}()
            @inferred maprule!(newsimdata, proc, opt, T, rule, rkeys, wkeys)
            
            resultdata = maprule!(simdata, rule)
            @test source(resultdata[:a]) == final
        end
    end
end

struct TestSetCell{R,W} <: SetCellRule{R,W} end
applyrule!(data, ::TestSetCell, state, index) = 0

@testset "A partial rule that returns zero does nothing" begin
    rule = TestSetCell()
    mask = nothing
    for proc in (SingleCPU(), ThreadedCPU()), opt in (NoOpt(), SparseOpt())
        @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
            ruleset = Ruleset(rule; opt=NoOpt())
            # Test type stability
            ext = Extent(; init=(_default_=init,), tspan=1:1)
            simdata = SimData(ext, ruleset)
            rkeys, rgrids = _getreadgrids(rule, simdata)
            wkeys, wgrids = _getwritegrids(rule, simdata)
            newsimdata = @set simdata.grids = _combinegrids(wkeys, wgrids, rkeys, rgrids)
            T = Val{DynamicGrids.ruletype(rule)}()
            @inferred maprule!(newsimdata, proc, opt, T, rule, rkeys, wkeys)
            resultdata = maprule!(simdata, rule)
            @test source(resultdata[:_default_]) == init
        end
    end
end

struct TestSetCellWrite{R,W} <: SetCellRule{R,W} end
applyrule!(data, ::TestSetCellWrite{R,W}, state, index) where {R,W} = add!(data[W], 1, index[1], 2)

@testset "A partial rule that writes to dest affects output" begin
    init  = [0 1 1 0
             0 1 1 0
             0 1 1 0
             0 1 1 0
             0 1 1 0]
    final = [0 5 1 0;
             0 5 1 0;
             0 5 1 0;
             0 5 1 0;
             0 5 1 0]
    for proc in hardware, opt in (NoOpt(), SparseOpt())
        @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
            rule = TestSetCellWrite()
            ruleset = Ruleset(rule; opt=opt, proc=proc)
            ext = Extent(; init=(_default_=init,), tspan=1:1)
            simdata = DynamicGrids._proc_setup(SimData(ext, ruleset));
            resultdata = maprule!(simdata, rule);
            @test Array(source(first(resultdata))) == final
        end
    end
end

struct TestCellTriple{R,W} <: CellRule{R,W} end
applyrule(data, ::TestCellTriple, state, index) = 3state

struct TestCellSquare{R,W} <: CellRule{R,W} end
applyrule(data, ::TestCellSquare, (state,), index) = state^2

@testset "Chained cell rules work" begin
    init  = [0 1 2 3;
             4 5 6 7]
    final = [0 9 36 81;
             144 225 324 441]
    for proc in hardware, opt in (NoOpt(), SparseOpt())
        @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
            rule = Chain(TestCellTriple(), TestCellSquare())
            ruleset = Ruleset(rule; opt=opt, proc=proc)
            ext = Extent(; init=(_default_=init,), tspan=1:1)
            simdata = DynamicGrids._proc_setup(SimData(ext, ruleset))
            resultdata = maprule!(simdata, rule);
            @test Array(source(first(resultdata))) == final
        end
    end
end

struct PrecalcRule{R,W,P} <: CellRule{R,W}
    precalc::P
end
DynamicGrids.modifyrule(rule::PrecalcRule, simdata) = PrecalcRule(currenttime(simdata))
applyrule(data, rule::PrecalcRule, state, index) = rule.precalc[]

@testset "Rule precalculations work" begin
    init  = [1 1;
             1 1]
    out2  = [2 2;
             2 2]
    out3  = [3 3;
             3 3]
    for proc in hardware, opt in (NoOpt(), SparseOpt())
        @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
            rule = PrecalcRule(1)
            ruleset = Ruleset(rule; proc=proc, opt=opt)
            output = ArrayOutput(init; tspan=1:3)
            sim!(output, ruleset)
            # Copy for GPU
            @test output[2] == out2
            @test output[3] == out3
        end
    end
end


# Multi grid rules

struct DoubleY{R,W} <: CellRule{R,W} end
applyrule(data, rule::DoubleY, (x, y), index) = y * 2

struct HalfX{R,W} <: CellRule{R,W} end
applyrule(data, rule::HalfX, x, index) = x, x * 0.5

struct Predation{R,W} <: CellRule{R,W} end
Predation(; prey=:prey, predator=:predator) = 
    Predation{Tuple{predator,prey},Tuple{prey,predator}}()
applyrule(data, ::Predation, (predators, prey), index) = begin
    caught = 2predators
    # Output order is the reverse of input to test that can work
    prey - caught, predators + caught * 0.5
end

predation = Predation(; prey=:prey, predator=:predator)

@testset "Multi-grid keys are inferred" begin
    @test _writekeys(predation) == (:prey, :predator)
    @test _readkeys(predation) == (:predator, :prey)
    @test keys(predation) == (:prey, :predator)
    @inferred _writekeys(predation)
    @inferred _readkeys(predation)
    @inferred keys(predation)
end

@testset "Multi-grid rules work" begin
    init = (prey=[10. 10.], predator=[1. 0.])
    rules = DoubleY{Tuple{:predator,:prey},:prey}(), predation
    output = ArrayOutput(init; tspan=1:3)
    for proc in hardware, opt in (NoOpt(), SparseOpt())
        @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
            sim!(output, rules; opt=opt, proc=proc)
            @test output[2] == (prey=[18. 20.], predator=[2. 0.])
            @test output[3] == (prey=[32. 40.], predator=[4. 0.])
        end
    end
end

@testset "Multi-grid rules work" begin
    init = (prey=[10. 10.], predator=[0. 0.])
    output = ArrayOutput(init; tspan=1:3)
    for proc in hardware, opt in (NoOpt(), SparseOpt())
        @testset "$(nameof(typeof(opt))) $(nameof(typeof(proc)))" begin
            ruleset = Ruleset((HalfX{:prey,Tuple{:prey,:predator}}(),); opt=opt, proc=proc)
            sim!(output, ruleset)
            @test output[2] == (prey=[10. 10.], predator=[5. 5.])
            @test output[3] == (prey=[10. 10.], predator=[5. 5.])
        end
    end
end

@testset "life with generic constructors" begin
    @test Life(Moore(1), (1, 1), (5, 5)) ==
        Life(; neighborhood=Moore(1), born=(1, 1), survive=(5, 5))
    @test Life{:a,:b}(Moore(1), (7, 1), (5, 3)) ==
          Life{:a,:b}(neighborhood=Moore(1), born=(7, 1), survive=(5, 3))
    # Defaults
    @test Life() == Life(
        Moore(1), 
        Param(3, bounds=(0, 8)),
        (Param(2, bounds=(0, 8)), Param(3, bounds=(0, 8)))
    )
    @test Life{:a,:b}() == Life{:a,:b}(
         Moore(1), 
         Param(3, bounds=(0, 8)),
         (Param(2, bounds=(0, 8)), Param(3, bounds=(0, 8)))
    )
end

@testset "generic ConstructionBase compatability" begin
    life = Life{:x,:y}(; neighborhood=Moore(2), born=(1, 1), survive=(2, 2))
    @set! life.born = (5, 6)
    @test life.born == (5, 6)
    @test life.survive == (2, 2)
    @test _readkeys(life) == :x
    @test _writekeys(life) == :y
    @test DynamicGrids.neighborhood(life) == Moore(2)
end
