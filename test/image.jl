using DynamicGrids, Test, Colors, ColorSchemes, FieldDefaults
using DynamicGrids: normaliseframe, frametoimage, @Image, @Output
using ColorSchemes: leonardo

init = [8.0 10.0;
        0.0  5.0]

# Define a simple image output
@Image @Output struct ImageOutput{} <: AbstractImageOutput{T} end
processor = Nothing
output = ImageOutput(init, minval=0.0, maxval=10.0)

ruleset = Ruleset(Life())

# Test level normalisation
normed = normaliseframe(output, output[1])
@test normed == [0.8 1.0
                 0.0 0.5]

# Test greyscale Image conversion
@test frametoimage(ColorProcessor(zerocolor=RGB24(1.0,0.0,0.0)), output, ruleset, init, 1) ==
    [RGB24(0.8, 0.8, 0.8) RGB24(1.0, 1.0, 1.0)
     RGB24(1.0, 0.0, 0.0) RGB24(0.5, 0.5, 0.5)]

l0 = RGB24(get(leonardo, 0))
l05 = RGB24(get(leonardo, 0.5))
l08 = RGB24(get(leonardo, 0.8))
l1 = RGB24(get(leonardo, 1))
@test frametoimage(ColorProcessor(;scheme=leonardo), output, ruleset, init, 1) == [l08 l1
                                                                                   l0 l05]
z0 = RGB24(1, 0, 0)
@test frametoimage(ColorProcessor(;scheme=leonardo, zerocolor=z0), output, ruleset, init, 1) == [l08 l1
                                                                                                 z0 l05]
