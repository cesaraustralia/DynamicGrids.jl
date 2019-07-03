using CellularAutomataBase, Test, Colors, ColorSchemes
using CellularAutomataBase: frametoimage
using ColorSchemes: leonardo

init = [1.0 1.0;
        0.0 0.5]

output = ArrayOutput(init, false)

# Greyscale is the default when there is no processor
@test frametoimage(output, init, 1) == [RGB24(1.0, 1.0, 1.0) RGB24(1.0, 1.0, 1.0)
                                        RGB24(0.0, 0.0, 0.0) RGB24(0.5, 0.5, 0.5)]

@test frametoimage(GreyscaleZerosProcessor(RGB24(1.0,0.0,0.0)), output, init, 1) == 
    [RGB24(1.0, 1.0, 1.0) RGB24(1.0, 1.0, 1.0)
     RGB24(1.0, 0.0, 0.0) RGB24(0.5, 0.5, 0.5)]

l0 = RGB24(get(leonardo, 0))
l05 = RGB24(get(leonardo, 0.5))
l1 = RGB24(get(leonardo, 1))
@test frametoimage(ColorSchemeProcessor(leonardo), output, init, 1) == [l1 l1
                                                                        l0 l05] 
z0 = RGB24(1, 0, 0)
@test frametoimage(ColorSchemeZerosProcessor(leonardo, z0), output, init, 1) == [l1 l1
                                                                                 z0 l05]
