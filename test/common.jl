using CellularAutomataBase, Test, Images
using CellularAutomataBase: process_frame, normalize_frame, is_showable, curframe, 
                            allocate_frames!, store_frame!, @Frames, @MinMax

@MinMax @Frames struct MinMaxOutput{} <: AbstractOutput{T} end

init = [10.0 11.0;
        0.0   5.0]

output = MinMaxOutput(init, 0.0, 10.0)

@test curframe(output, 5) == 5 
@test is_showable(output, 5) == false

update = [8.0 15.0;
          2.0  9.0]

@test length(output) == 1
push!(output, update)
@test length(output) == 2
@test output[2] == update

allocate_frames!(output, init, 3:5)

@test length(output) == 5
@test firstindex(output) == 1
@test lastindex(output) == 5
@test size(output) == (5,)

@test output[3] != update
store_frame!(output, update, 3)
@test output[3] == update

output2 = MinMaxOutput(output, 0.0, 10.0)
@test length(output2) == 5
@test output2[3] == update


@testset "image processing" begin
    @test normalize_frame(output, output[1]) == [1.0 1.0;
                                                 0.0 0.5]

    @test process_frame(output, output[1], 1) == [RGB24(1.0, 1.0, 1.0) RGB24(1.0, 1.0, 1.0);
                                                  RGB24(0.0, 0.0, 0.0) RGB24(0.5, 0.5, 0.5)]
end
