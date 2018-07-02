using Cellular

@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

@testset "inbounds checks" begin
    @testset "Skip" begin
        @test Cellular.inbounds((1,1), (4, 5), Skip()) == (1,1,true)
        @test Cellular.inbounds((2,3), (4, 5), Skip()) == (2,3,true)
        @test Cellular.inbounds((4,5), (4, 5), Skip()) == (4,5,true)

        @test Cellular.inbounds((-3,-100), (4, 5), Skip()) == (-3,-100,false)
        @test Cellular.inbounds((0,0), (4, 5), Skip()) == (0,0,false)
        @test Cellular.inbounds((2,3), (3, 2), Skip()) == (2,3,false)
        @test Cellular.inbounds((2,3), (1, 4), Skip()) == (2,3,false)
        @test Cellular.inbounds((200,300), (2, 3), Skip()) == (200,300,false)
    end

    @testset "Wrap" begin
        @test Cellular.inbounds((-2,3), (10, 10), Wrap()) == (8,3,true)
        @test Cellular.inbounds((2,0), (10, 10), Wrap()) == (2,10,true)
        @test Cellular.inbounds((22,0), (10, 10), Wrap()) == (2,10,true)
        @test Cellular.inbounds((-22,0), (10, 10), Wrap()) == (8,10,true)
    end
end

@testset "life glider simulation" begin

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

    output = ArrayOutput(init)
    out = sim!(output, Life(), init;  time = 1:5)

    @test output.frames[3] == test
    @test output.frames[5] == test2
end

# TODO: the rest of the tests...

