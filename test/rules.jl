using DynamicGrids, ModelParameters, Setfield, Test, StaticArrays
import DynamicGrids: applyrule, applyrule!, maprule!, extent,
       source, dest, currenttime, getreadgrids, getwritegrids, combinegrids,
       SimData, WritableGridData, Rule, Extent, readkeys, writekeys

init  = [0 1 1 0
         0 1 1 0
         0 1 1 0
         0 1 1 0
         0 1 1 0]

@testset "Generic rule constructors" begin
   rule1 = Cell{:a,:b}(identity)
   @test rule1.f == identity
   @test_throws ArgumentError Cell()
   @test_throws ArgumentError Cell(identity, identity)
   rule1 = Neighbors{:a,:b}(identity, Moore(1))
   @test rule1.f == identity
   rule2 = Neighbors{:a,:b}(identity; neighborhood=Moore(1))
   @test rule1 == rule2
   @test typeof(rule1)  == Neighbors{:a,:b,typeof(identity),Moore{1,Nothing}}
   rule1 = Neighbors(identity, Moore(1))
   @test rule1.f == identity
   rule2 = Neighbors(identity; neighborhood=Moore(1))
   @test typeof(rule1)  == Neighbors{:_default_,:_default_,typeof(identity),Moore{1,Nothing}}
   @test rule1 == rule2
   @test_throws ArgumentError Neighbors()
   @test_throws ArgumentError Neighbors(identity, identity, identity)
   rule1 = SetNeighbors{:a,:b}(identity, Moore(1))
   @test rule1.f == identity
   rule2 = SetNeighbors{:a,:b}(identity; neighborhood=Moore(1))
   @test rule1 == rule2
   @test typeof(rule1)  == SetNeighbors{:a,:b,typeof(identity),Moore{1,Nothing}}
   rule1 = SetNeighbors(identity, Moore(1))
   @test rule1.f == identity
   rule2 = SetNeighbors(identity; neighborhood=Moore(1))
   @test typeof(rule1)  == SetNeighbors{:_default_,:_default_,typeof(identity),Moore{1,Nothing}}
   @test rule1 == rule2
   @test_throws ArgumentError Neighbors()
   @test_throws ArgumentError Neighbors(identity, identity, identity)
   rule1 = Manual{:a,:b}(identity)
   @test rule1.f == identity
   @test_throws ArgumentError Manual()
   @test_throws ArgumentError Manual(identity, identity)
end


@testset "Cell" begin
    rule = Cell(x -> 2x)
    @test applyrule(nothing, rule, 1, (0, 0)) == 2
end

@testset "Neighbors" begin
    buf = [1 0 0; 0 0 1; 0 0 1]
    rule = Neighbors(VonNeumann(1, buf)) do hood, state
        sum(hood)
    end
    @test applyrule(nothing, rule, 0, (3, 3)) == 1
    rule = Neighbors(Moore(1, buf)) do hood, state
        sum(hood)
    end
    @test applyrule(nothing, rule, 0, (3, 3)) == 3
end

@testset "Convolution" begin
    k = SA[1 0 1; 0 0 0; 1 0 1]
    buf = SA[1 0 0; 0 0 1; 0 0 1]
    rule = Convolution(Kernel(k, buf))
    @test applyrule(nothing, rule, 0, (3, 3)) == 2
    output = ArrayOutput(init; tspan=1:2)
    sim!(output, rule)
end

@testset "SetNeighbors" begin
    init  = [0 1 0 0
             0 0 0 0
             0 0 0 0
             0 1 0 0
             0 0 1 0]
    rule = SetNeighbors(VonNeumann(1)) do data, hood, I, state
        if state > 0
            for pos in positions(hood, I)
                add!(first(data), 1, pos...) 
            end
        end
    end
    output = ArrayOutput(init; tspan=1:2)
    data = SimData(extent(output), Ruleset(rule)) 
    # Cant use applyrule! without a lot of work on SimData
    # so just trun the whole thing
    sim!(output, rule)
    @test output[2] == [1 1 1 0
                        0 1 0 0
                        0 1 0 0
                        1 1 2 0
                        0 2 1 1]
end

@testset "Manual" begin
    init  = [0 1 0 0
             0 0 0 0
             0 0 0 0
             0 1 0 0
             0 0 1 0]
    rule = Manual() do data, I, state
        if state > 0
            pos = I[1] - 2, I[2]
            isinbounds(pos, data) && add!(first(data), 1, pos...)
        end
    end

    output = ArrayOutput(init; tspan=1:2)
    data = SimData(extent(output), Ruleset(rule)) 
    # Cant use applyrule! without a lot of work on SimData
    # so just trun the whole thing
    sim!(output, rule)
    @test output[2] == [0 1 0 0
                        0 1 0 0
                        0 0 1 0
                        0 1 0 0
                        0 0 1 0]
end

@testset "Grid" begin
    rule = Grid() do r, w
        w .*= 2
    end

    init  = [0 1 0 0
             0 0 0 0
             0 0 0 0
             0 1 0 0
             0 0 1 0]

    output = ArrayOutput(init; tspan=1:2)
    data = SimData(extent(output), Ruleset(rule)) 
    # Cant use applyrule! without a lot of work on SimData
    # so just trun the whole thing
    sim!(output, rule)
    @test output[2] == [0 2 0 0
                        0 0 0 0
                        0 0 0 0
                        0 2 0 0
                        0 0 2 0]
end


struct AddOneRule{R,W} <: Rule{R,W} end
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

struct TestRule{R,W} <: Rule{R,W} end
applyrule(data, ::TestRule, state, index) = 0

@testset "A rule that returns zero gives zero outputs" begin
    final = [0 0 0 0
             0 0 0 0
             0 0 0 0
             0 0 0 0
             0 0 0 0]

    rule = TestRule{:a,:a}()
    ruleset1 = Ruleset(rule; opt=NoOpt())
    ruleset2 = Ruleset(rule; opt=SparseOpt())
    mask = nothing

    @test DynamicGrids.overflow(ruleset1) === RemoveOverflow()
    @test DynamicGrids.opt(ruleset1) === NoOpt()
    @test DynamicGrids.opt(ruleset2) === SparseOpt()
    @test DynamicGrids.cellsize(ruleset1) === 1
    @test DynamicGrids.timestep(ruleset1) === nothing
    @test DynamicGrids.ruleset(ruleset1) === ruleset1

    extent = Extent(; init=(a=init,), tspan=1:1)
    simdata1 = SimData(extent, ruleset1)
    simdata2 = SimData(extent, ruleset2)

    # Test maprules components
    rkeys, rgrids = getreadgrids(rule, simdata1)
    wkeys, wgrids = getwritegrids(rule, simdata1)
    @test rkeys == Val{:a}()
    @test wkeys == Val{:a}()
    newsimdata = @set simdata1.grids = combinegrids(rkeys, rgrids, wkeys, wgrids)
    @test newsimdata.grids[1] isa WritableGridData
    # Test type stability
    @inferred maprule!(newsimdata, NoOpt(), rule, rkeys, rgrids, wkeys, wgrids, mask)
    
    resultdata1 = maprule!(simdata1, rule)
    resultdata2 = maprule!(simdata2, rule)
    @test source(resultdata1[:a]) == final
    @test source(resultdata2[:a]) == final
end

struct TestManual{R,W} <: ManualRule{R,W} end
applyrule!(data, ::TestManual, state, index) = 0

@testset "A partial rule that returns zero does nothing" begin
    rule = TestManual()
    ruleset1 = Ruleset(rule; opt=NoOpt())
    ruleset2 = Ruleset(rule; opt=SparseOpt())
    mask = nothing
    # Test type stability
    extent = Extent(; init=(_default_=init,), tspan=1:1)
    simdata1 = SimData(extent, ruleset1)
    simdata2 = SimData(extent, ruleset2)
    rkeys, rgrids = getreadgrids(rule, simdata1)
    wkeys, wgrids = getwritegrids(rule, simdata1)
    newsimdata = @set simdata1.grids = combinegrids(wkeys, wgrids, rkeys, rgrids)

    @inferred maprule!(newsimdata, NoOpt(), rule, rkeys, rgrids, wkeys, wgrids, mask)
    @inferred maprule!(newsimdata, SparseOpt(), rule, rkeys, rgrids, wkeys, wgrids, mask)

    resultdata1 = maprule!(simdata1, rule)
    resultdata2 = maprule!(simdata2, rule)
    @test source(resultdata1[:_default_]) == init
    @test source(resultdata2[:_default_]) == init
end

struct TestManualWrite{R,W} <: ManualRule{R,W} end
applyrule!(data, ::TestManualWrite{R,W}, state, index) where {R,W} = add!(data[W], 1, index[1], 2)

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

    rule = TestManualWrite()
    ruleset1 = Ruleset(rule; opt=NoOpt())
    ruleset2 = Ruleset(rule; opt=SparseOpt())
    ext = Extent(; init=(_default_=init,), tspan=1:1)
    simdata1 = SimData(ext, ruleset1)
    simdata2 = SimData(ext, ruleset2)
    resultdata1 = maprule!(simdata1, rule)
    resultdata2 = maprule!(simdata2, rule)
    @test source(first(resultdata1)) == final
    @test source(first(resultdata2)) == final
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
    rule = Chain(TestCellTriple(), 
                 TestCellSquare())
    ruleset1 = Ruleset(rule; opt=NoOpt())
    ruleset2 = Ruleset(rule; opt=SparseOpt())
    ext = Extent(; init=(_default_=init,), tspan=1:1)
    simdata1 = SimData(ext, ruleset1)
    simdata2 = SimData(ext, ruleset2)
    resultdata1 = maprule!(simdata1, rule);
    resultdata2 = maprule!(simdata2, rule);
    @test source(first(resultdata1)) == final
    @test source(first(resultdata2)) == final
end


struct PrecalcRule{R,W,P} <: Rule{R,W}
    precalc::P
end
DynamicGrids.precalcrules(rule::PrecalcRule, simdata) = 
    PrecalcRule(currenttime(simdata))
applyrule(data, rule::PrecalcRule, state, index) = rule.precalc[]

@testset "Rule precalculations work" begin
    init  = [1 1;
             1 1]

    out2  = [2 2;
             2 2]

    out3  = [3 3;
             3 3]

    rule = PrecalcRule(1)
    ruleset = Ruleset(rule)
    output = ArrayOutput(init; tspan=1:3)
    sim!(output, ruleset)
    @test output[2] == out2
    @test output[3] == out3
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
    @test writekeys(predation) == (:prey, :predator)
    @test readkeys(predation) == (:predator, :prey)
    @test keys(predation) == (:prey, :predator)
    @inferred writekeys(predation)
    @inferred readkeys(predation)
    @inferred keys(predation)
end

@testset "Multi-grid keys are inferred" begin
    @test writekeys(predation) == (:prey, :predator)
    @test readkeys(predation) == (:predator, :prey)
    @test keys(predation) == (:prey, :predator)
    @inferred writekeys(predation)
    @inferred readkeys(predation)
    @inferred keys(predation)
end

@testset "Multi-grid rules work" begin
    init = (prey=[10. 10.], predator=[1. 0.])
    ruleset1 = Ruleset(DoubleY{Tuple{:predator,:prey},:prey}(), predation; opt=NoOpt())
    ruleset2 = Ruleset(DoubleY{Tuple{:predator,:prey},:prey}(), predation; opt=SparseOpt())
    output1 = ArrayOutput(init; tspan=1:3)
    output2 = ArrayOutput(init; tspan=1:3)
    sim!(output1, ruleset1)
    sim!(output2, ruleset2)
    @test output1[2] == (prey=[18. 20.], predator=[2. 0.])
    @test output2[2] == (prey=[18. 20.], predator=[2. 0.])
    @test output1[3] == (prey=[32. 40.], predator=[4. 0.])
    @test output2[3] == (prey=[32. 40.], predator=[4. 0.])
end

@testset "Multi-grid rules work" begin
    init = (prey=[10. 10.], predator=[0. 0.])
    ruleset1 = Ruleset(HalfX{:prey,Tuple{:prey,:predator}}(); opt=NoOpt())
    ruleset2 = Ruleset(HalfX{:prey,Tuple{:prey,:predator}}(); opt=SparseOpt())
    output1 = ArrayOutput(init; tspan=1:3)
    output2 = ArrayOutput(init; tspan=1:3)
    sim!(output1, ruleset1)
    sim!(output2, ruleset2)
    @test output1[2] == (prey=[10. 10.], predator=[5. 5.])
    @test output2[2] == (prey=[10. 10.], predator=[5. 5.])
    @test output1[3] == (prey=[10. 10.], predator=[5. 5.])
    @test output2[3] == (prey=[10. 10.], predator=[5. 5.])
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
    @test readkeys(life) == :x
    @test writekeys(life) == :y
    @test DynamicGrids.neighborhood(life) == Moore(2)
end
