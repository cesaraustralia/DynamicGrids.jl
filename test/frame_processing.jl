using DynamicGrids, Test, Colors, ColorSchemes
using DynamicGrids: frametoimage, @Output
using ColorSchemes: leonardo

init = [1.0 1.0;
        0.0 0.5]

@Output struct ImageOutput{} <: AbstractImageOutput{T} end
output = ImageOutput(init, false)

ruleset = Ruleset()

@test frametoimage(ColorProcessor(zerocolor=RGB24(1.0,0.0,0.0)), output, ruleset, init, 1) ==
    [RGB24(1.0, 1.0, 1.0) RGB24(1.0, 1.0, 1.0)
     RGB24(1.0, 0.0, 0.0) RGB24(0.5, 0.5, 0.5)]

l0 = RGB24(get(leonardo, 0))
l05 = RGB24(get(leonardo, 0.5))
l1 = RGB24(get(leonardo, 1))
@test frametoimage(ColorProcessor(;scheme=leonardo), output, ruleset, init, 1) == [l1 l1
                                                                                  l0 l05]
z0 = RGB24(1, 0, 0)
@test frametoimage(ColorProcessor(;scheme=leonardo, zerocolor=z0), output, ruleset, init, 1) == [l1 l1
                                                                                                z0 l05]
