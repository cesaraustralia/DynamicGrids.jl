using DynamicGrids, Test

# Reducing functions may return the original grid, 
# not a copy, so we need to be careful with them.

@testset "Reducing functions over NamedTuple" begin
    rule = Cell{:a}() do data, state, I
        state + 10
    end
    @testset "single named grid" begin
        init = (a=[1 3],)
        transformed_output = TransformedOutput(sum, init; tspan=1:3)
        @test length(transformed_output) == 3
        @test transformed_output[1] == [1 3]
        @test transformed_output[2] == [0 0]
        @test transformed_output[3] == [0 0]

        sim!(transformed_output, rule)
        @test transformed_output[1] == [1 3]
        @test transformed_output[2] == [11 13]
        @test transformed_output[3] == [21 23]
    end

    @testset "multiple named grids" begin
        init = (a=[1 3], b=[5 5],)
        transformed_output = TransformedOutput(sum, init; tspan=1:3)
        @test length(transformed_output) == 3
        @test transformed_output[1] == [6 8]
        @test transformed_output[2] == [0 0]
        @test transformed_output[3] == [0 0]

        sim!(transformed_output, rule)
        @test transformed_output[1] == [6 8]
        @test transformed_output[2] == [16 18]
        @test transformed_output[3] == [26 28]
    end
end

@testset "Reducing functions over Array" begin
    rule = Cell() do data, state, I
        state + 10.0
    end
    init = [1 3]
    transformed_output = TransformedOutput(sum, init; tspan=1:3)
    @test length(transformed_output) == 3
    @test transformed_output[1] == 4
    @test transformed_output[2] == 0
    @test transformed_output[3] == 0

    sim!(transformed_output, rule)
    @test transformed_output[1] == 4
    @test transformed_output[2] == 24
    @test transformed_output[3] == 44
end
