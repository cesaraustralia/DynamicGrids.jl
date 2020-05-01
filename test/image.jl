using DynamicGrids, Test, Colors, ColorSchemes, FieldDefaults
using DynamicGrids: grid2image, @Image, @Graphic, @Output, 
    processor, minval, maxval, normalise, SimData, isstored, isasync,
    initialise, finalise, delay, fps, showfps, settimestamp!, timestamp, 
    tspan, setfps!, frames, isshowable, Red, Green, Blue, showgrid
using ColorSchemes: leonardo

init = [8.0 10.0;
        0.0  5.0]

l0 = RGB24(get(leonardo, 0))
l05 = RGB24(get(leonardo, 0.5))
l08 = RGB24(get(leonardo, 0.8))
l1 = RGB24(get(leonardo, 1))

# Define a simple image output
@Image @Graphic @Output mutable struct TestImageOutput{} <: ImageOutput{T} end

DynamicGrids.showimage(image, o::TestImageOutput, f, t) = image 

@testset "basic ImageOutput" begin
    output = TestImageOutput(init)
    output = TestImageOutput(output)

    @test parent(output) == [init]
    @test showfps(output) === 25.0
    @test minval(output) === 0
    @test maxval(output) === 1
    @test processor(output) == ColorProcessor()
    @test isasync(output) == false
    @test isstored(output) == false
    @test initialise(output) === nothing
    @test finalise(output) === nothing
    @test delay(output, 1.0) === nothing
    @test timestamp(output) === 0.0
    pre = time()
    settimestamp!(output, 1)
    @test timestamp(output) > pre
    @test length(output) == 1
    push!(output, 2init)
    @test length(output) == 2
    @test output[2] == 2init
    @test tspan(output) == (1, 1)
    @test fps(output) === 25.0
    @test setfps!(output, 1000.0) === 1000.0
    @test fps(output) === 1000.0
    output[1] = 5init
    @test frames(output)[1] == 5init
    @test isshowable(output, 1)

    @test showgrid(output, 1, 1) ==
        [RGB24(1.0,1.0,1.0) RGB24(1.0,1.0,1.0)
         RGB24(0.0,0.0,0.0) RGB24(1.0,1.0,1.0)]
    savegif("test.gif", output)
    @test isfile("test.gif")

    arrayoutput = ArrayOutput([0 0], 2)
    @test minval(arrayoutput) == 0
    @test maxval(arrayoutput) == 1
    @test processor(arrayoutput) == Greyscale()
    @test fps(arrayoutput) === nothing
    @test showfps(arrayoutput) === nothing

    TestImageOutput(arrayoutput)
end


@testset "ColorProcessor" begin
    proc = ColorProcessor(zerocolor=(1.0,0.0,0.0))
    output = TestImageOutput((a=init,); processor=proc, minval=nothing, maxval=10.0, store=true)
    @test minval(output) === nothing
    @test maxval(output) === 10.0
    @test processor(output) == ColorProcessor(zerocolor=(1.0,0.0,0.0))
    @test isstored(output) == true

    simdata = SimData(init, Ruleset(Life()), 1)

    # Test level normalisation
    normed = normalise.(output[1][:a], minval(output), maxval(output))
    @test normed == [0.8 1.0
                     0.0 0.5]

    # Test greyscale Image conversion
    @test grid2image(processor(output), output, simdata, init, 1) ==
        [RGB24(0.8, 0.8, 0.8) RGB24(1.0, 1.0, 1.0)
         RGB24(1.0, 0.0, 0.0) RGB24(0.5, 0.5, 0.5)]

    @test grid2image(ColorProcessor(;scheme=leonardo), output, simdata, init, 1) == [l08 l1
                                                                                     l0 l05]
    z0 = RGB24(1, 0, 0)
    proc = ColorProcessor(scheme=leonardo, zerocolor=z0)
    @test grid2image(proc, output, simdata, init, 1) == [l08 l1
                                                         z0 l05]
end

@testset "LayoutProcessor" begin
    z0 = RGB24(1, 0, 0)
    grey = ColorProcessor(zerocolor=z0)
    leo = ColorProcessor(scheme=leonardo, zerocolor=z0)
    multiinit = (a = init, b = 2init)
    proc = LayoutProcessor([:a, nothing, :b], (grey, leo))
    output = TestImageOutput(init; processor=proc, minval=(0, nothing), maxval=(10, 20), store=true)
    @test minval(output) === (0, nothing)
    @test maxval(output) === (10, 20)
    @test processor(output) === proc
    @test isstored(output) == true

    # Test image is joined from :a, nothing, :b
    @test grid2image(processor(output), output, Ruleset(), multiinit, 1) ==
        [RGB24(0.8, 0.8, 0.8) RGB24(1.0, 1.0, 1.0)
         RGB24(1.0, 0.0, 0.0) RGB24(0.5, 0.5, 0.5)
         RGB24(0.0, 0.0, 0.0) RGB24(0.0, 0.0, 0.0)
         RGB24(0.0, 0.0, 0.0) RGB24(0.0, 0.0, 0.0)
         l08                  l1
         z0                   l05                 ]

end

@testset "ThreeColorProcessor" begin
    mask = Bool[1 1 1 1 0]
    multiinit = (a=[5.0 5.0 4.0 4.0 5.0], 
                 b=[0.1 0.2 0.0 0.0 4.0], 
                 c=[5.0 5.0 10.0 5.0 0.6],
                 d=[9.0 0.0 15.0 50.0 -10.0])
    proc = ThreeColorProcessor(colors=(Green(), Red(), Blue(), nothing), zerocolor=0.9, maskcolor=0.8)
    @test proc.colors === (Green(), Red(), Blue(), nothing)
    output = TestImageOutput(multiinit; processor=proc, minval=(4, nothing, 5, nothing), maxval=(6, nothing, 10, nothing), store=true)
    @test minval(output) === (4, nothing, 5, nothing)
    @test maxval(output) === (6, nothing, 10, nothing)
    @test processor(output) === proc

    # Test image is combined from red and green overlays
    @test grid2image(processor(output), output, Ruleset(mask=mask), multiinit, 1) ==
        [RGB24(0.1, 0.5, 0.0) RGB24(0.2, 0.5, 0.0) RGB24(0.0, 0.0, 1.0) RGB24(0.9, 0.9, 0.9) RGB24(0.8, 0.8, 0.8)]
end
