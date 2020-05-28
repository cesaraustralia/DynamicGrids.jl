using DynamicGrids, Dates, Test, Colors, ColorSchemes, FieldDefaults
using FreeTypeAbstraction
using DynamicGrids: grid2image, @Image, @Graphic, @Output,
    processor, minval, maxval, normalise, SimData, isstored, isasync,
    initialise, finalise, delay, fps, settimestamp!, timestamp,
    tspan, setfps!, frames, isshowable, Red, Green, Blue, showgrid, rgb, scale
using ColorSchemes: leonardo

@testset "rgb" begin
    @test rgb(0.5) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test rgb(0.5, 0.5, 0.5) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test rgb(0.5, 0.5, 0.5, 1.0) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test rgb((0.5, 0.5, 0.5)) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test rgb((0.5, 0.5, 0.5, 1.0)) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test rgb(RGB(0.5, 0.5, 0.5)) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test rgb(ARGB32(0.5, 0.5, 0.5)) === ARGB32(0.5, 0.5, 0.5, 1.0)
end

@testset "normalise" begin
    @test normalise(-.2, 0.0, 1.0) == 0.0
    @test normalise(1.2, 0.0, 1.0) == 1.0
    @test normalise(-.2, 0.0, nothing) == 0.0
    @test normalise(1.2, nothing, 1.0) == 1.0
    @test normalise(1.2, nothing, nothing) == 1.2
end

@testset "scale" begin
    @test scale(0.0, 5.0, 10.0) == 5.0
    @test scale(0.5, 5.0, 10.0) == 7.5
    @test scale(1.0, nothing, 10.0) == 10.0
    @test scale(0.0, -2.0, nothing) == -2.0
    @test scale(1.2, nothing, nothing) == 1.2
end

init = [8.0 10.0;
        0.0  5.0]

l0 = ARGB32(get(leonardo, 0))
l05 = ARGB32(get(leonardo, 0.5))
l08 = ARGB32(get(leonardo, 0.8))
l1 = ARGB32(get(leonardo, 1))

# Define a simple image output
@Image @Graphic @Output mutable struct TestImageOutput{} <: ImageOutput{T} end

TestImageOutput(; kwargs...) = TestImageOutput(values(kwargs)...)

global images = []

DynamicGrids.showimage(image, o::TestImageOutput, f, t) = begin
    push!(images, image)
    image
end

@testset "basic ImageOutput" begin
    output = TestImageOutput(init; tspan=1:1)

    @test parent(output) == [init]
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
    @test tspan(output) == 1:1
    @test fps(output) === 25.0
    @test setfps!(output, 1000.0) === 1000.0
    @test fps(output) === 1000.0
    output[1] = 5init
    @test frames(output)[1] == 5init
    @test isshowable(output, 1)

    @test showgrid(output, 1, 1) ==
        [ARGB32(1.0,1.0,1.0) ARGB32(1.0,1.0,1.0)
         ARGB32(0.0,0.0,0.0) ARGB32(1.0,1.0,1.0)]
    savegif("test.gif", output)
    @test isfile("test.gif")

    arrayoutput = ArrayOutput([0 0]; tspan=1:2)
    @test minval(arrayoutput) == 0
    @test maxval(arrayoutput) == 1
    @test processor(arrayoutput) == ColorProcessor()
    @test fps(arrayoutput) === nothing
end


@testset "ColorProcessor" begin
    proc = ColorProcessor(zerocolor=(1.0,0.0,0.0))
    output = TestImageOutput((a=init,); tspan=1:1, processor=proc, minval=0.0, maxval=10.0, store=true)
    @test minval(output) === 0.0
    @test maxval(output) === 10.0
    @test processor(output) == ColorProcessor(zerocolor=(1.0,0.0,0.0))
    @test isstored(output) == true
    simdata = SimData(init, nothing, Ruleset(Life()), 1)

    # Test level normalisation
    normed = normalise.(output[1][:a], minval(output), maxval(output))
    @test normed == [0.8 1.0
                     0.0 0.5]

    # Test greyscale Image conversion
    @test grid2image(processor(output), output, simdata, (a=init,), 1) ==
        [ARGB32(0.8, 0.8, 0.8) ARGB32(1.0, 1.0, 1.0)
         ARGB32(1.0, 0.0, 0.0) ARGB32(0.5, 0.5, 0.5)]

    proc = ColorProcessor(;scheme=leonardo)
    @test grid2image(proc, output, simdata, init, 1) == [l08 l1
                                                         l0 l05]
    z0 = ARGB32(1, 0, 0)
    proc = ColorProcessor(scheme=leonardo, zerocolor=z0)
    @test grid2image(proc, output, simdata, init, 1) == [l08 l1
                                                         z0 l05]

    @testset "text captions" begin
        font = "arial"
        pixelsize = 20
        timepos = 2pixelsize, pixelsize
        textinit = zeros(200, 200)
        face = findfont(font)
        if face === nothing
            font = "cantarell"
            face = findfont(font)
        end
        refimg = ARGB32.(map(x -> ARGB32(1.0, 0.0, 0.0, 1.0), textinit))
        renderstring!(refimg, string(DateTime(2001)), face, pixelsize, timepos...;
                      fcolor=ARGB32(1.0, 1.0, 1.0, 1.0), bcolor=ARGB32(0.0, 0.0, 0.0, 1.0))
        textconfig=TextConfig(; font=font, timepixels=pixelsize, namepixels=pixelsize)
        proc = ColorProcessor(zerocolor=ARGB32(1.0, 0.0, 0.0, 1.0), textconfig=textconfig)
        output = TestImageOutput((t=textinit,); tspan=1:1, processor=proc, store=true)
        img = grid2image(proc, output, simdata, textinit, DateTime(2001))
        @test img == refimg
    end
    
end

@testset "SparseOptInspector" begin
    init =  [
             0 0 0 0 0 0 0
             0 0 0 0 1 1 1
             0 0 0 0 0 0 1
             0 0 0 0 0 1 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
            ]
    ruleset = Ruleset(;
        rules=(Life(),),
            init=init,
        timestep=Day(1),
        overflow=WrapOverflow(),
        opt=SparseOpt(),
    )
    proc = SparseOptInspector()
    output = TestImageOutput(init; 
        tspan=Date(2001, 1, 1):Day(1):Date(2001, 1, 5), 
        processor=proc, minval=0.0, maxval=1.0, store=true
    )

    @test minval(output) === 0.0
    @test maxval(output) === 1.0
    @test processor(output) == SparseOptInspector()
    @test isstored(output) == true

    global images = []
    sim!(output, ruleset)
    w, y, c = ARGB32(1), ARGB32(.5, .5, 0), ARGB32(0., .5, .5)
    @test images[1] == [
             y y y y y y y
             y y y c w w w
             y y y c c c w
             y y y y y w c
             y y y y y c c
             y y y y y y y
            ]

end

@testset "LayoutProcessor" begin
    z0 = ARGB32(1, 0, 0)
    grey = ColorProcessor(zerocolor=z0)
    leo = ColorProcessor(scheme=leonardo, zerocolor=z0)
    multiinit = (a = init, b = 2init)
    proc = LayoutProcessor([:a, nothing, :b], (grey, leo), nothing)
    output = TestImageOutput(init; tspan=1:1, processor=proc, minval=(0, 0), maxval=(10, 20), store=true)
    @test minval(output) === (0, 0)
    @test maxval(output) === (10, 20)
    @test processor(output) === proc
    @test isstored(output) == true
    simdata = SimData(init, nothing, Ruleset(Life()), 1)

    # Test image is joined from :a, nothing, :b
    @test grid2image(output, Ruleset(), multiinit, 1) ==
        [ARGB32(0.8, 0.8, 0.8) ARGB32(1.0, 1.0, 1.0)
         ARGB32(1.0, 0.0, 0.0) ARGB32(0.5, 0.5, 0.5)
         ARGB32(0.0, 0.0, 0.0) ARGB32(0.0, 0.0, 0.0)
         ARGB32(0.0, 0.0, 0.0) ARGB32(0.0, 0.0, 0.0)
         l08                  l1
         z0                   l05                 ]

    @testset "text captions" begin
        font = "arial"
        timepixels = 20
        timepos = 2timepixels, timepixels
        textinit = (a=zeros(200, 200), b=zeros(200, 200))
        face = findfont(font)
        if face === nothing
            font = "cantarell"
            face = findfont(font)
        end
        refimg = cat(fill(ARGB32(1, 0, 0), 200, 200), fill(ARGB32(0), 200, 200), fill(ARGB32(1, 0, 0), 200, 200); dims=1)
        renderstring!(refimg, string(DateTime(2001)), face, timepixels, timepos...;
                      fcolor=ARGB32(RGB(1.0), 1.0), bcolor=ARGB32(RGB(0.0), 1.0))

        namepixels = 15
        nameposa = 3timepixels + namepixels, timepixels
        renderstring!(refimg, "a", face, namepixels, nameposa...;
                      fcolor=ARGB32(RGB(1.0), 1.0), bcolor=ARGB32(RGB(0.0), 1.0))
        nameposb = 3timepixels + namepixels + 400, timepixels
        renderstring!(refimg, "b", face, namepixels, nameposb...;
                      fcolor=ARGB32(RGB(1.0), 1.0), bcolor=ARGB32(RGB(0.0), 1.0))

        textconfig = TextConfig(; font=font, timepixels=timepixels, namepixels=namepixels)
        proc = LayoutProcessor([:a, nothing, :b], (grey, leo), textconfig)

        output = TestImageOutput((t=textinit,); tspan=1:10, processor=proc, store=true, 
                                 minval=(0, 0), maxval=(1, 1))

        img = grid2image(output, simdata, textinit, DateTime(2001));
        @test img == refimg
    end
end

@testset "ThreeColorProcessor" begin
    mask = Bool[1 1 1 1 0]
    multiinit = (a=[5.0 5.0 4.0 4.0 5.0],
                 b=[0.1 0.2 0.0 0.0 4.0],
                 c=[5.0 5.0 10.0 5.0 0.6],
                 d=[9.0 0.0 15.0 50.0 -10.0])
    proc = ThreeColorProcessor(colors=(Green(), Red(), Blue(), nothing), zerocolor=0.9, maskcolor=0.8)
    @test proc.colors === (Green(), Red(), Blue(), nothing)
    output = TestImageOutput(multiinit; 
        mask=mask, tspan=1:1, processor=proc, 
        minval=(4, 0, 5, 0), maxval=(6, 1, 10, 1), store=true
    )
    @test minval(output) === (4, 0, 5, 0)
    @test maxval(output) === (6, 1, 10, 1)
    @test processor(output) === proc

    # Test image is combined from red and green overlays
    @test grid2image(processor(output), output, Ruleset(), multiinit, 1) ==
        [ARGB32(0.1, 0.5, 0.0) ARGB32(0.2, 0.5, 0.0) ARGB32(0.0, 0.0, 1.0) ARGB32(0.9, 0.9, 0.9) ARGB32(0.8, 0.8, 0.8)]
end
