using DynamicGrids, DimensionalData, Dates, Test
using DynamicGrids: isshowable, frameindex, storeframe!, SimData, stoppedframe

# Mostly outputs are tested in integration.jl
@testset "Output construction" begin
    init = [10.0 11.0
            0.0   5.0]

    output = ArrayOutput(init; tspan=Date(2001):Year(1):Date(2010))
    ruleset = Ruleset(Life())

    @test length(output) == 10
    @test size(output) == (10,)
    @test step(output) == Year(1)
    @test stoppedframe(output) == 10
    @test timestep(output) == Year(1)
    @test_throws ArgumentError DynamicGrids.ruleset(output)
    @test frameindex(output, 5) == 5 
    @test isshowable(output, 5) == false
    @test output[1] == output[Ti(1)] == init

    @testset "DimensionalData interface" begin
        @test output isa AbstractDimArray{<:Array,1,<:Tuple{<:Ti}}
        @test dims(output) isa Tuple{<:Ti}
        @test DimensionalData.name(output) == NoName()
        @test metadata(output) == NoMetadata()
        da = output[Ti(Between(Date(2002), Date(2003)))]
        @test da isa DimArray{<:Array,1,<:Tuple{<:Ti}}
        @test index(da) == (Date(2002):Year(1):Date(2002),)
    end

    @testset "errors" begin
        @test_throws UndefKeywordError ArrayOutput(ones(5, 5))
        @test_throws ArgumentError ArrayOutput((a=ones(5, 5), b=ones(4, 4)); tspan=1:10)
        @test_throws ArgumentError ArrayOutput(ones(5, 5); mask=ones(2, 2), tspan=1:10)
    end
end
