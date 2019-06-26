using CellularAutomataBase, Test
import CellularAutomataBase: rule, rule!

struct TestModel <: AbstractModel end
struct TestPartial <: AbstractPartialModel end
struct TestPartialWrite <: AbstractPartialModel end

rule(::TestModel, data, state, index, args...) = 0
rule!(::TestPartial, data, state, index, args...) = 0
rule!(::TestPartialWrite, data, state, index, args...) = data.dest[index[1], 2] = 0


@testset "builds indices matrix" begin
    @test broadcastable_indices([1 2 3; 3 4 5]) == [(1, 1) (1, 2) (1, 3); (2, 1) (2, 2) (2, 3)]
end


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

    model = Models(TestModel(); init=init)
    output = ArrayOutput(init, 10)
    sim!(output, model; tstop=10)
    @test output[10] == final
end

@testset "an partial rule that returns zero does nothing" begin
    model = Models(TestPartial(); init=init)
    output = ArrayOutput(init, 10)
    sim!(output, model; tstop=10)
    @test output[1] == init
    @test output[10] == init
end

@testset "a partial rule that writes to dest affects output" begin
    final = [0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0]

    model = Models(TestPartialWrite(); init=init)
    output = ArrayOutput(init, 10)
    sim!(output, model; tstop=10)
    @test output[1] == init
    @test output[2] == final
    @test output[10] == final

end

