using Cellular

@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

@testset "inbounds checks" begin
    @test Cellular.inbounds((2,3), (4, 5), Skip()) == (2,3,true)
    @test Cellular.inbounds((2,3), (3, 2), Skip()) == (2,3,false)
    @test Cellular.inbounds((2,3), (1, 4), Skip()) == (2,3,false)

    @test Cellular.inbounds((-2,3), (10, 10), Wrap()) == (8,3,true)
    @test Cellular.inbounds((2,0), (10, 10), Wrap()) == (2,10,true)
end

@testset "life glider simulation" begin

    init = [0 0 0 0 0 0;
            0 0 0 0 0 0;
            0 0 1 1 1 0;
            0 0 0 0 1 0;
            0 0 0 1 0 0;
            0 0 0 0 0 0]

    test = [0 0 0 0 0 0;
            0 0 0 1 1 0;
            0 0 1 0 1 0;
            0 0 0 0 1 0;
            0 0 0 0 0 0;
            0 0 0 0 0 0]

    output = ArrayOutput(init)
    out = sim!(output, Life(), init;  time = 1:3)

    @test output.frames[3] == test
end

# TODO: the rest of the tests...

