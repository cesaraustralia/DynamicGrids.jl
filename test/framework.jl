using DynamicGrids, Test, Setfield
import DynamicGrids: applyrule, applyrule!, maprule!, 
       SimData, source, dest, currenttime, 
       Read, Write, getdata, combinedata, ruleloop

init  = [0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0]

struct TestRule{R,W} <: Rule{R,W} end
applyrule(::TestRule, data, state, index) = 0

@testset "a rule that returns zero gives zero outputs" begin
    final = [0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0]

    rule = TestRule{:test,:test}()
    ruleset = Ruleset(rule; init=init)
    simdata = SimData((test=init,), ruleset, 1)

    # Test type stability
    rkeys, rdata = getdata(Read(), rule, simdata)
    wkeys, wdata = getdata(Write(), rule, simdata)
    newsimdata = @set simdata.data = combinedata(wkeys, wdata, rkeys, rdata)
    @inferred ruleloop(rule, newsimdata, rkeys, rdata, wkeys, wdata)
    
    resultdata = maprule!(simdata, rule)
    @test source(resultdata[:test]) == final
end

struct TestPartial{R,W} <: PartialRule{R,W} end
applyrule!(::TestPartial, data, state, index) = 0

@testset "a partial rule that returns zero does nothing" begin
    rule = TestPartial{:test,:test}()
    ruleset = Ruleset(rule; init=init)
    # Test type stability
    simdata = SimData((test=init,), ruleset, 1)
    rkeys, rdata = getdata(Read(), rule, simdata)
    wkeys, wdata = getdata(Write(), rule, simdata)
    newsimdata = @set simdata.data = combinedata(wkeys, wdata, rkeys, rdata)
    @inferred ruleloop(rule, newsimdata, rkeys, rdata, wkeys, wdata)

    resultdata = maprule!(simdata, rule)
    @test source(first(resultdata)) == init
end

struct TestPartialWrite{R,W} <: PartialRule{R,W} end
applyrule!(::TestPartialWrite, data, state, index) = data[:test][index[1], 2] = 0

@testset "a partial rule that writes to dest affects output" begin
    final = [0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0]

    rule = TestPartialWrite{:test,:test}()
    ruleset = Ruleset(rule; init=init)
    simdata = SimData((test=init,), ruleset, 1)
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
    rule = Chain(TestCellTriple{:test,:test}(), 
                 TestCellSquare{:test,:test}())
    ruleset = Ruleset(rule; init=(test=init,))
    simdata = SimData((test=init,), ruleset, 1)
    resultdata = maprule!(simdata, ruleset.rules[1]);
    @test source(first(resultdata)) == final
end

struct PrecalcRule{R,W,P} <: Rule{R,W}
    precalc::P
end
DynamicGrids.precalcrules(rule::PrecalcRule, data) = 
    PrecalcRule{:test,:test}(currenttime(data))
applyrule(rule::PrecalcRule, data, state, index) = rule.precalc[]

@testset "a rule with precalculations" begin
    init  = [1 1;
             1 1]

    out2  = [2 2;
             2 2]

    out3  = [3 3;
             3 3]

    rule = PrecalcRule{:test,:test}(1)
    ruleset = Ruleset(rule; init=(test=init,))
    output = ArrayOutput((test=init,), 3)
    sim!(output, ruleset; tspan=(1, 3))
    @test output[2][:test] == out2
    @test output[3][:test] == out3
end


