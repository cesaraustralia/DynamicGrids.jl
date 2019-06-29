using CellularAutomataBase, Test
import CellularAutomataBase: applyrule, applyrule!

struct TestRule <: AbstractRule end
struct TestPartial <: AbstractPartialRule end
struct TestPartialWrite <: AbstractPartialRule end

applyrule(::TestRule, data, state, index) = 0
applyrule!(::TestPartial, data, state, index) = 0
applyrule!(::TestPartialWrite, data, state, index) = data.dest[index[1], 2] = 0


init  = [0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0]

@testset "a rule that returns zero gives zero outputs" begin
    final = [0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0]

    rule = Ruleset(TestRule(); init=init)
    output = ArrayOutput(init, 10)
    sim!(output, rule; tstop=10)
    @test output[10] == final
end

@testset "an partial rule that returns zero does nothing" begin
    rule = Ruleset(TestPartial(); init=init)
    output = ArrayOutput(init, 10)
    sim!(output, rule; tstop=10)
    @test output[1] == init
    @test output[10] == init
end

@testset "a partial rule that writes to dest affects output" begin
    final = [0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0]

    rule = Ruleset(TestPartialWrite(); init=init)
    output = ArrayOutput(init, 10)
    sim!(output, rule; tstop=10)
    @test output[1] == init
    @test output[2] == final
    @test output[10] == final

end

