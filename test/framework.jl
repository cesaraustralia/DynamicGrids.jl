using DynamicGrids, Setfield, FieldDefaults, FieldMetadata, Test
import DynamicGrids: applyrule, applyrule!, maprule!, 
       source, dest, currenttime, getdata, combinedata, ruleloop,
       SimData, WritableGridData, _Read_, _Write_,
       Rule, readkeys, writekeys, @Image, @Graphic, @Output

# Single grid rules

init  = [0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0]

struct TestRule{R,W} <: Rule{R,W} end
applyrule(::TestRule, data, state, index) = 0

@testset "Must include init" begin
    output = ArrayOutput(init, 7)
    ruleset = Ruleset()
    @test_throws ArgumentError sim!(output, ruleset)
end

@testset "a rule that returns zero gives zero outputs" begin
    final = [0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0]

    rule = TestRule()
    ruleset = Ruleset(rule; init=init)

    @test DynamicGrids.init(ruleset) === init
    @test DynamicGrids.mask(ruleset) === nothing
    @test DynamicGrids.overflow(ruleset) === RemoveOverflow()
    @test DynamicGrids.opt(ruleset) === SparseOpt()
    @test DynamicGrids.cellsize(ruleset) === 1
    @test DynamicGrids.timestep(ruleset) === 1
    @test DynamicGrids.ruleset(ruleset) === ruleset

    simdata = SimData(init, ruleset, 1)

    # Test maprules components
    rkeys, rdata = getdata(_Read_(), rule, simdata)
    wkeys, wdata = getdata(_Write_(), rule, simdata)
    @test rkeys == Val{:_default_}()
    @test wkeys == Val{:_default_}()
    newsimdata = @set simdata.data = combinedata(rkeys, rdata, wkeys, wdata)
    @test newsimdata.data[1] isa WritableGridData
    # Test type stability
    @inferred ruleloop(NoOpt(), rule, newsimdata, rkeys, rdata, wkeys, wdata)
    
    resultdata = maprule!(simdata, rule)
    @test source(resultdata[:_default_]) == final
end

struct TestPartial{R,W} <: PartialRule{R,W} end
applyrule!(::TestPartial, data, state, index) = 0

@testset "a partial rule that returns zero does nothing" begin
    rule = TestPartial()
    ruleset = Ruleset(rule; init=init)
    # Test type stability
    simdata = SimData(init, ruleset, 1)
    rkeys, rdata = getdata(_Read_(), rule, simdata)
    wkeys, wdata = getdata(_Write_(), rule, simdata)
    newsimdata = @set simdata.data = combinedata(wkeys, wdata, rkeys, rdata)

    @inferred ruleloop(NoOpt(), rule, newsimdata, rkeys, rdata, wkeys, wdata)

    resultdata = maprule!(simdata, rule)
    @test source(resultdata[:_default_]) == init
end

struct TestPartialWrite{R,W} <: PartialRule{R,W} end
applyrule!(::TestPartialWrite, data, state, index) = data[:_default_][index[1], 2] = 0

@testset "a partial rule that writes to dest affects output" begin
    final = [0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0]

    rule = TestPartialWrite()
    ruleset = Ruleset(rule; init=init)
    simdata = SimData(init, ruleset, 1)
    resultdata = maprule!(simdata, rule)
    @test source(first(resultdata)) == final
end

struct TestCellTriple{R,W} <: CellRule{R,W} end
applyrule(::TestCellTriple, data, state, index) = 3state

struct TestCellSquare{R,W} <: CellRule{R,W} end
applyrule(::TestCellSquare, data, (state,), index) = state^2

@testset "a chained cell rull" begin
    init  = [0 1 2 3;
             4 5 6 7]

    final = [0 9 36 81;
             144 225 324 441]
    rule = Chain(TestCellTriple(), 
                 TestCellSquare())
    ruleset = Ruleset(rule; init=init)
    simdata = SimData(init, ruleset, 1)
    resultdata = maprule!(simdata, ruleset.rules[1]);
    @test source(first(resultdata)) == final
end


struct PrecalcRule{R,W,P} <: Rule{R,W}
    precalc::P
end
DynamicGrids.precalcrules(rule::PrecalcRule, data) = 
    PrecalcRule(currenttime(data))
applyrule(rule::PrecalcRule, data, state, index) = rule.precalc[]

@testset "a rule with precalculations" begin
    init  = [1 1;
             1 1]

    out2  = [2 2;
             2 2]

    out3  = [3 3;
             3 3]

    rule = PrecalcRule(1)
    ruleset = Ruleset(rule; init=init)
    output = ArrayOutput(init, 3)
    sim!(output, ruleset; tspan=(1, 3))
    @test output[2] == out2
    @test output[3] == out3
end


# Multi grid rules

struct Double{R,W} <: CellRule{R,W} end
applyrule(rule::Double, data, (predators, prey), index) = prey * 2

struct Predation{R,W} <: CellRule{R,W} end
Predation(; prey=:prey, predator=:predator) = 
    Predation{Tuple{predator,prey},Tuple{prey,predator}}()
applyrule(::Predation, data, (predators, prey), index) = begin
    caught = 2predators
    # Output order is the reverse of input to test that can work
    prey - caught, predators + caught * 0.5
end

predation = Predation(; prey=:prey, predator=:predator)
preyarray = [10. 10.]
predatorarray = [1. 0.]
init = (prey=preyarray, predator=predatorarray)

@testset "multi-grid keys are inferred" begin
    @test writekeys(predation) == (:prey, :predator)
    @test readkeys(predation) == (:predator, :prey)
    @test keys(predation) == (:prey, :predator)
    @inferred writekeys(predation)
    @inferred readkeys(predation)
    @inferred keys(predation)
end

@testset "multi-grid keys are inferred" begin
    @test writekeys(predation) == (:prey, :predator)
    @test readkeys(predation) == (:predator, :prey)
    @test keys(predation) == (:prey, :predator)
    @inferred writekeys(predation)
    @inferred readkeys(predation)
    @inferred keys(predation)
end

@testset "a multi-grid predator prey rule" begin
    ruleset = Ruleset(Double{Tuple{:predator,:prey},:prey}(), predation)
    output = ArrayOutput(init, 12)
    sim!(output, ruleset; init=init, tspan=(1, 3))
    @test output[2] == (prey=[18. 20], predator=[2.0 0.0])
    @test output[3] == (prey=[32. 40], predator=[4.0 0.0])
end
