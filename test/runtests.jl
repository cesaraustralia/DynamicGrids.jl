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
    source = zeros(Int8, 6, 6)
    source[3, 3] = 1
    source[3, 4] = 1
    source[5, 4] = 1
    source[3, 5] = 1
    source[4, 5] = 1
    source

    test = zeros(Int8, 6, 6)
    test[2, 4] = 1
    test[3, 3] = 1
    test[2, 5] = 1
    test[3, 5] = 1
    test[4, 5] = 1
    test

    source
    output = ArrayOutput(source)
    output.frames
    out = sim!(source, Life(), output; time = 1:3)

    @test output.frames[3] == test
end

# TODO: the rest of the tests...

