using Cellular
@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

@testset "build dispersal kernel" begin
    dk = Cellular.build_dispersal_kernel(d->e^-d, 1)
    @test typeof(dk) == Array{Float64,2}
    @test size(dk, 1) == 3
    @test size(dk, 2) == 3
    @test dk[1,1] == dk[3,3] == dk[3,1] == dk[1,3]
    @test dk[2,1] == dk[1,2] == dk[3,2] == dk[2,3]
end

@testset "inbounds checks" begin
    @test Cellular.inbounds((2,3), (4, 5), Skip()) == (2,3,true)
    @test Cellular.inbounds((2,3), (3, 2), Skip()) == (2,3,false)
    @test Cellular.inbounds((2,3), (1, 4), Skip()) == (2,3,false)

    @test Cellular.inbounds((-2,3), (10, 10), Wrap()) == (8,3,true)
    @test Cellular.inbounds((2,0), (10, 10), Wrap()) == (2,10,true)
end

@testset "life glider" begin
    model = Life()

    source = zeros(Int8, 6, 6)
    source[3, 3] = 1
    source[3, 4] = 1
    source[5, 4] = 1
    source[3, 5] = 1
    source[4, 5] = 1
    source
    dest = similar(source)

    test = zeros(Int8, 6, 6)
    test[2, 4] = 1
    test[3, 3] = 1
    test[2, 5] = 1
    test[3, 5] = 1
    test[4, 5] = 1
    test

    automate!(dest, source, model)
    automate!(source, dest, model)
    automate!(dest, source, model)

    @test source == test
end

# TODO: the rest of the tests...
