using DynamicGrids, Test
import DynamicGrids: applyrule, applyrule!, maprule!, 
       SimData, source, dest, currenttime

init  = [0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0]

struct TestRule <: Rule end
applyrule(::TestRule, data, state, index) = 0

@testset "a rule that returns zero gives zero outputs" begin
    final = [0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0]

    ruleset = Ruleset(TestRule(); init=init)
    data = SimData(ruleset, init, 1)
    maprule!(data, ruleset.rules[1])
    @test dest(data) == final
end

struct TestPartial <: PartialRule end
applyrule!(::TestPartial, data, state, index) = 0

@testset "a partial rule that returns zero does nothing" begin
    ruleset = Ruleset(TestPartial(); init=init)
    data = SimData(ruleset, init, 1)
    maprule!(data, ruleset.rules[1])
    @test dest(data) == init
end

struct TestPartialWrite <: PartialRule end
applyrule!(::TestPartialWrite, data, state, index) = data[index[1], 2] = 0

@testset "a partial rule that writes to dest affects output" begin
    final = [0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0]

    ruleset = Ruleset(TestPartialWrite(); init=init)
    data = SimData(ruleset, init, 1)
    maprule!(data, ruleset.rules[1])
    @test dest(data) == final
end

struct TestCellTriple <: CellRule end
applyrule(::TestCellTriple, data, state, index) = 3state

struct TestCellSquare <: CellRule end
applyrule(::TestCellSquare, data, state, index) = state^2

@testset "a chained cell rull" begin
    init  = [0 1 2 3;
             4 5 6 7]

    final = [0 9 36 81;
             144 225 324 441]

    ruleset = Ruleset(Chain(TestCellTriple(), TestCellSquare()); init=init)
    data = SimData(ruleset, init, 1)
    maprule!(data, ruleset.rules[1])
    @test dest(data) == final
end

struct PrecalcRule{P} <: Rule 
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

    ruleset = Ruleset(PrecalcRule(1); init=init)
    output = ArrayOutput(init, 3)
    sim!(output, ruleset; tspan=(1, 3))
    @test output[2] == out2
    @test output[3] == out3
end
