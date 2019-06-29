using CellularAutomataBase, Test, Colors
using CellularAutomataBase: processframe, normalizeframe, isshowable, curframe, 
                            allocateframes!, storeframe!, @Output, @MinMax

@MinMax @Output struct MinMaxOutput{} <: AbstractOutput{T} end

init = [10.0 11.0;
        0.0   5.0]

output = MinMaxOutput(init, false, 0.0, 10.0)

@test curframe(output, 5) == 5 
@test isshowable(output, 5) == false

update = [8.0 15.0;
          2.0  9.0]

@test length(output) == 1
push!(output, update)
@test length(output) == 2
@test output[2] == update

allocateframes!(output, init, 3:5)

@test length(output) == 5
@test firstindex(output) == 1
@test lastindex(output) == 5
@test size(output) == (5,)

@test output[3] != update
storeframe!(output, update, 3)
@test output[3] == update

output2 = MinMaxOutput(output, false, 0.0, 10.0)
@test length(output2) == 5
@test output2[3] == update


@testset "image processing" begin
    @test normalizeframe(output, output[1]) == [1.0 1.0;
                                                 0.0 0.5]

    @test processframe(output, output[1], 1) == [RGB24(1.0, 1.0, 1.0) RGB24(1.0, 1.0, 1.0);
                                                  RGB24(0.0, 0.0, 0.0) RGB24(0.5, 0.5, 0.5)]
end
