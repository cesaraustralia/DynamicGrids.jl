using DynamicGrids, Test
import DynamicGrids: applyrule, applyrule!, maprule!, simdata, source, dest

init  = [0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0]

struct TestRule <: AbstractRule end
applyrule(::TestRule, data, state, index) = 0

@testset "a rule that returns zero gives zero outputs" begin
    final = [0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0]

    ruleset = Ruleset(TestRule(); init=init)
    data = simdata(ruleset, init)
    maprule!(data, ruleset.rules[1])
    @test dest(data) == final
end

struct TestPartial <: AbstractPartialRule end
applyrule!(::TestPartial, data, state, index) = 0

@testset "a partial rule that returns zero does nothing" begin
    ruleset = Ruleset(TestPartial(); init=init)
    data = simdata(ruleset, init)
    maprule!(data, ruleset.rules[1])
    @test dest(data) == init
end

struct TestPartialWrite <: AbstractPartialRule end
applyrule!(::TestPartialWrite, data, state, index) = data[index[1], 2] = 0

@testset "a partial rule that writes to dest affects output" begin
    final = [0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0]

    ruleset = Ruleset(TestPartialWrite(); init=init)
    data = simdata(ruleset, init)
    maprule!(data, ruleset.rules[1])
    @test dest(data) == final
end

struct TestCellTriple <: AbstractCellRule end
applyrule(::TestCellTriple, data, state, index) = 3state

struct TestCellSquare <: AbstractCellRule end
applyrule(::TestCellSquare, data, state, index) = state^2

@testset "a chained cell rull" begin
    init  = [0 1 2 3;
             4 5 6 7]

    final = [0 9 36 81;
             144 225 324 441]

    ruleset = Ruleset(Chain(TestCellTriple(), TestCellSquare()); init=init)
    data = simdata(ruleset, init)
    maprule!(data, ruleset.rules[1])
    @test dest(data) == final
end
