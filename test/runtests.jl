using Revise
using Cellular
import Cellular: rule, neighbors

@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

@testset "boundary overflow checks are working" begin
    @testset "inbounds with Skip() returns index and false for an overflowed index" begin
        @test Cellular.inbounds((1,1), (4, 5), Skip()) == (1,1,true)
        @test Cellular.inbounds((2,3), (4, 5), Skip()) == (2,3,true)
        @test Cellular.inbounds((4,5), (4, 5), Skip()) == (4,5,true)

        @test Cellular.inbounds((-3,-100), (4, 5), Skip()) == (-3,-100,false)
        @test Cellular.inbounds((0,0), (4, 5), Skip()) == (0,0,false)
        @test Cellular.inbounds((2,3), (3, 2), Skip()) == (2,3,false)
        @test Cellular.inbounds((2,3), (1, 4), Skip()) == (2,3,false)
        @test Cellular.inbounds((200,300), (2, 3), Skip()) == (200,300,false)
    end

    @testset "inbounds with Wrap() returns new index and true for an overflowed index" begin
        @test Cellular.inbounds((-2,3), (10, 10), Wrap()) == (8,3,true)
        @test Cellular.inbounds((2,0), (10, 10), Wrap()) == (2,10,true)
        @test Cellular.inbounds((22,0), (10, 10), Wrap()) == (2,10,true)
        @test Cellular.inbounds((-22,0), (10, 10), Wrap()) == (8,10,true)
    end
end

struct TestModel <: AbstractModel end
struct TestPartial <: AbstractPartialModel end
struct TestPartialWrite <: AbstractPartialModel end

rule(::TestModel, args...) = 0
rule(::TestPartial, args...) = 0
rule(::TestPartialWrite, state, index, t, source, dest, args...) = dest[index[1], 2] = 0

init  = [0 1 1 0;
         0 1 1 0;
         0 1 1 0;
         0 1 1 0]

@testset "a rule that returns zero gives zero outputs" begin
    final = [0 0 0 0;
             0 0 0 0;
             0 0 0 0;
             0 0 0 0]

    model = TestModel()
    output = ArrayOutput(init)
    sim!(output, model, init; time=1:10)
    @test output[10] == final
end

@testset "an partial rule that just returns zero does nothing" begin
    model = TestPartial()
    output = ArrayOutput(init)
    sim!(output, model, init; time=1:10)
    @test output[1] == init
    @test output[10] == init
end

@testset "a partial rule that writes to dest affects output" begin
    final = [0 0 1 0;
             0 0 1 0;
             0 0 1 0;
             0 0 1 0]

    model = TestPartialWrite()
    output = ArrayOutput(init)
    sim!(output, model, init; time=1:10)
    @test output[1] == init
    @test output[2] == final
    @test output[10] == final
end

@testset "neighborhoods sum surrounding values correctly" begin
    source = [0 0 0 1 1 1;
              1 0 1 1 0 1;
              0 1 1 1 1 1;
              0 1 0 0 1 0;
              0 0 0 0 1 1;
              0 1 0 1 1 0]

    moore = RadialNeighborhood(typ=:moore, radius=1, overflow=Wrap())
    vonneumann = RadialNeighborhood(typ=:vonneumann, radius=1, overflow=Wrap())
    rotvonneumann = RadialNeighborhood(typ=:rotvonneumann, radius=1, overflow=Wrap())
    custom = CustomNeighborhood(((-1,-1), (-1,2), (0,0)), Wrap())
    multi = MultiCustomNeighborhood(multi=(((-1,1), (-3,2)), ((1,2), (2,2))), overflow=Wrap())
    state = 0
    t = 1

    @test neighbors(moore, state, (6, 2), t, source) == 0
    @test neighbors(vonneumann, state, (6, 2), t, source) == 0
    @test neighbors(rotvonneumann, state, (6, 2), t, source) == 0

    @test neighbors(moore, state, (2, 5), t, source) == 8
    @test neighbors(vonneumann, state, (2, 5), t, source) == 4
    @test neighbors(rotvonneumann, state, (2, 5), t, source) == 4

    @test neighbors(moore, state, (4, 4), t, source) == 5
    @test neighbors(vonneumann, state, (4, 4), t, source) == 2
    @test neighbors(rotvonneumann, state, (4, 4), t, source) == 3

    @test neighbors(custom, state, (1, 1), t, source) == 0
    @test neighbors(custom, state, (3, 3), t, source) == 1
    @test neighbors(multi, state, (1, 1), t, source) == [1, 2]
end

@testset "life glider does its thing" begin

    init = [0 0 0 0 0 0;
            0 0 0 0 0 0;
            0 0 0 0 0 0;
            0 0 0 1 1 1;
            0 0 0 0 0 1;
            0 0 0 0 1 0]

    test = [0 0 0 0 0 0;
            0 0 0 0 0 0;
            0 0 0 0 1 1;
            0 0 0 1 0 1;
            0 0 0 0 0 1;
            0 0 0 0 0 0]

    test2= [0 0 0 0 0 0;
            0 0 0 0 0 0;
            1 0 0 0 1 1;
            1 0 0 0 0 0;
            0 0 0 0 0 1;
            0 0 0 0 0 0]

    output = REPLOutput(init)
    sim!(output, Life(), init;  time = 1:5)
    sleep(0.1)

    @testset "stored results match glider behaviour" begin
        @test output[3] == test
        @test output[5] == test2
    end

    @testset "converted results match glider behaviour" begin
        output = ArrayOutput(output)
        @test output[3] == test
        @test output[5] == test2
        replay(output)
    end

    # @testset "Gtk output also works" begin
    #     output = GtkOutput(init)
    # end
end


# TODO test outputs? how...
