using Cellular, Test
import Cellular: rule, rule!

struct TestModel <: AbstractModel end
struct TestPartial <: AbstractPartialModel end
struct TestPartialWrite <: AbstractPartialModel end

rule(::TestModel, data, state, index, args...) = 0
rule!(::TestPartial, data, state, index, args...) = 0
rule!(::TestPartialWrite, data, state, index, args...) = data.dest[index[1], 2] = 0


@testset "boundary overflow checks are working" begin
    @testset "inbounds with Skip() returns index and false for an overflowed index" begin
        @test Cellular.inbounds((1, 1), (4, 5), Skip()) == ((1,1),true)
        @test Cellular.inbounds((2, 3), (4, 5), Skip()) == ((2,3),true)
        @test Cellular.inbounds((4, 5), (4, 5), Skip()) == ((4,5),true)
        @test Cellular.inbounds((-3, -100), (4, 5), Skip()) == ((-3,-100),false)
        @test Cellular.inbounds((0, 0), (4, 5), Skip()) == ((0,0),false)
        @test Cellular.inbounds((2, 3), (3, 2), Skip()) == ((2,3),false)
        @test Cellular.inbounds((2, 3), (1, 4), Skip()) == ((2,3),false)
        @test Cellular.inbounds((200, 300), (2, 3), Skip()) == ((200,300),false)
    end
    @testset "inbounds with Wrap() returns new index and true for an overflowed index" begin
        @test Cellular.inbounds((-2,3), (10, 10), Wrap()) == ((8,3),true)
        @test Cellular.inbounds((2,0), (10, 10), Wrap()) == ((2,10),true)
        @test Cellular.inbounds((22,0), (10, 10), Wrap()) == ((2,10),true)
        @test Cellular.inbounds((-22,0), (10, 10), Wrap()) == ((8,10),true)
    end
end


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

    model = Models(TestModel())
    output = ArrayOutput(init, 10)
    sim!(output, model, init; tstop=10)
    @test output[10] == final
end

@testset "an partial rule that returns zero does nothing" begin
    model = Models(TestPartial())
    output = ArrayOutput(init, 10)
    sim!(output, model, init; tstop=10)
    @test output[1] == init
    @test output[10] == init
end

@testset "a partial rule that writes to dest affects output" begin
    final = [0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0]

    model = Models(TestPartialWrite())
    output = ArrayOutput(init, 10)
    sim!(output, model, init; tstop=10)
    @test output[1] == init
    @test output[2] == final
    @test output[10] == final

end

