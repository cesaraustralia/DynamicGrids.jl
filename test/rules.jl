using DynamicGrids, Setfield, FieldMetadata, Test
import DynamicGrids: applyrule, applyrule!, maprule!, 
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
   rule2 = Cell(identity, read=:a, write=:b)
   @test rule1 == rule2
   @test_throws ArgumentError Cell()
   @test_throws ArgumentError Cell(identity, identity)
   @test_throws MethodError Cell{:a, :b}(identity, read=:x, write=:y)
   rule1 = Neighbors{:a,:b}(identity, Moore(1))
   @test rule1.f == identity
   rule2 = Neighbors(identity, read=:a, write=:b, neighborhood=Moore(1))
   # Moore(1) is the default value
   rule3 = Neighbors(identity, read=:a, write=:b)
   @test rule1 == rule2 == rule3
   @test_throws ArgumentError Neighbors()
   @test_throws ArgumentError Neighbors(identity, identity, identity)
   rule1 = Manual{:a,:b}(identity)
   @test rule1.f == identity
   rule2 = Manual(identity, read=:a, write=:b)
   @test rule1 == rule2
   @test_throws ArgumentError Manual()
   @test_throws ArgumentError Manual(identity, identity)
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
applyrule!(data, ::TestManualWrite, state, index) = data[:_default_][index[1], 2] = 0

@testset "A partial rule that writes to dest affects output" begin
    final = [0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0]

    rule = TestManualWrite()
    ruleset1 = Ruleset(rule; opt=NoOpt())
    ruleset2 = Ruleset(rule; opt=SparseOpt())
    extent = Extent(; init=(_default_=init,), tspan=1:1)
    simdata1 = SimData(extent, ruleset1)
    simdata2 = SimData(extent, ruleset2)
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
    extent = Extent(; init=(_default_=init,), tspan=1:1)
    simdata1 = SimData(extent, ruleset1)
    simdata2 = SimData(extent, ruleset2)
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
          Life(; neighborhood=Moore(1), birth=(1, 1), sustain=(5, 5))
    @test Life{:a,:b}(Moore(1), (1, 1), (5, 5)) ==
          Life(; read=:a, write=:b, neighborhood=Moore(1), birth=(1, 1), sustain=(5, 5));
    @test Life(read=:a, write=:b) == Life{:a,:b}()
    @test Life() == Life(; read=:_default_)
end

@testset "generic ConstructionBase compatability" begin
    life = Life{:x,:y}(; neighborhood=Moore(2), birth=(1, 1), sustain=(2, 2))
    @set! life.birth = (5, 6)
    @test life.birth == (5, 6)
    @test life.sustain == (2, 2)
    @test readkeys(life) == :x
    @test writekeys(life) == :y
    @test DynamicGrids.neighborhood(life) == Moore(2)
end
