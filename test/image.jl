using DynamicGrids, Test, Colors, ColorSchemes, FieldDefaults
using DynamicGrids: grid2image, @Image, @Graphic, @Output, minval, maxval, normalise, SimData
using ColorSchemes: leonardo

init = [8.0 10.0;
        0.0  5.0]

# Define a simple image output
@Image @Graphic @Output struct TestImageOutput{} <: ImageOutput{T} end
processor = Nothing
output = TestImageOutput(init, minval=0.0, maxval=10.0)

ruleset = Ruleset(Life())
simdata = SimData(init, ruleset, 1)

# Test level normalisation
normed = normalise.(output[1], minval(output), maxval(output))
@test normed == [0.8 1.0
                 0.0 0.5]

# Test greyscale Image conversion
@test grid2image(ColorProcessor(zerocolor=RGB24(1.0,0.0,0.0)), output, simdata, init, 1) ==
    [RGB24(0.8, 0.8, 0.8) RGB24(1.0, 1.0, 1.0)
     RGB24(1.0, 0.0, 0.0) RGB24(0.5, 0.5, 0.5)]

l0 = RGB24(get(leonardo, 0))
l05 = RGB24(get(leonardo, 0.5))
l08 = RGB24(get(leonardo, 0.8))
l1 = RGB24(get(leonardo, 1))
@test grid2image(ColorProcessor(;scheme=leonardo), output, simdata, init, 1) == [l08 l1
                                                                                 l0 l05]
z0 = RGB24(1, 0, 0)
@test grid2image(ColorProcessor(;scheme=leonardo, zerocolor=z0), output, simdata, init, 1) == [l08 l1
                                                                                               z0 l05]
