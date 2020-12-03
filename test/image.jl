using DynamicGrids, Dates, Test, Colors, ColorSchemes
using FreeTypeAbstraction
using DynamicGrids: grid2image, processor, minval, maxval, normalise, SimData, NoDisplayImageOutput,
    isstored, isasync, initialise, finalise, delay, fps, settimestamp!, timestamp,
    tspan, setfps!, frames, isshowable, Red, Green, Blue, showframe, rgb, scale, Extent, extent
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


l0 = ARGB32(get(leonardo, 0))
l05 = ARGB32(get(leonardo, 0.5))
l08 = ARGB32(get(leonardo, 0.8))
l1 = ARGB32(get(leonardo, 1))

images = []

DynamicGrids.showimage(image, o::NoDisplayImageOutput, f, t) = begin
    push!(images, image)
    image
end

@testset "basic ImageOutput" begin
    init_ = [8.0 10.0;
             0.0  5.0]
    output = NoDisplayImageOutput(init_; tspan=1:1, maxval=40.0)

    @test parent(output) == [init_]
    @test minval(output) === nothing
    @test maxval(output) === 40.0
    @test processor(output).scheme == Greyscale()
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
    push!(output, 2init_)
    @test length(output) == 2
    @test output[2] == 2init_
    @test tspan(output) == 1:1
    @test fps(output) === 25.0
    @test setfps!(output, 1000.0) === 1000.0
    @test fps(output) === 1000.0
    output[1] = 5init_
    @test frames(output)[1] == 5init_
    @test isshowable(output, 1)

    output = NoDisplayImageOutput(init_; tspan=1:10, maxval=40.0)
    simdata = SimData(extent(output), Ruleset(Life()))
    @test_broken showframe(output, simdata, 1, 1) ==
        [ARGB32(1.0, 1.0, 1.0) ARGB32(1.0, 1.0, 1.0)
         ARGB32(0.0, 0.0, 0.0) ARGB32(1.0, 1.0, 1.0)]
    savegif("test.gif", output)
    @test isfile("test.gif")
    rm("test.gif")

    arrayoutput = ArrayOutput([0 0]; tspan=1:2)
    @test minval(arrayoutput) == nothing
    @test maxval(arrayoutput) == nothing
    @test_broken processor(arrayoutput) == ColorProcessor()
    @test fps(arrayoutput) === nothing
end


@testset "ColorProcessor" begin
    init_ = [8.0 10.0;
             0.0  5.0]
    proc = ColorProcessor(zerocolor=(1.0, 0.0, 0.0); textconfig=nothing)
    ic = DynamicGrids.ImageConfig(init=init_, processor=proc)
    @test ic.processor === proc
    output = NoDisplayImageOutput((a=init_,); tspan=1:10, processor=proc, minval=0.0, maxval=10.0, store=true)
    @test processor(output) === output.imageconfig.processor === proc
    @test minval(output) === 0.0
    @test maxval(output) === 10.0
    @test processor(output).zerocolor == ColorProcessor(zerocolor=(1.0, 0.0, 0.0)).zerocolor
    @test isstored(output) == true
    simdata = SimData(extent(output), Ruleset(Life()))

    # Test level normalisation
    normed = normalise.(output[1][:a], minval(output), maxval(output))
    @test normed == [0.8 1.0
                     0.0 0.5]

    # Test greyscale Image conversion
    img = grid2image(processor(output), output, simdata, (a=init_,), 1, 1)
    @test img == [ARGB32(0.8, 0.8, 0.8, 1.0) ARGB32(1.0, 1.0, 1.0, 1.0)
                  ARGB32(1.0, 0.0, 0.0, 1.0) ARGB32(0.5, 0.5, 0.5, 1.0)]

    proc = ColorProcessor(; scheme=leonardo, textconfig=nothing)
    img = grid2image(proc, output, simdata, init_, 1, 1)
    @test img == [l08 l1
                  DynamicGrids.ZEROCOL l05]
    z0 = ARGB32(1, 0, 0)
    proc = ColorProcessor(scheme=leonardo, zerocolor=z0, textconfig=nothing)
    img = grid2image(proc, output, simdata, init_, 1, 1)
    @test img == [l08 l1
                  z0 l05]

    @testset "text captions" begin
        pixelsize = 20
        timepos = 2pixelsize, pixelsize
        textinit = zeros(200, 200)
        font = "arial"
        face = findfont(font)
        # Swap fonts on linux
        if face === nothing
            font = "cantarell"
            face = findfont(font)
        end
        if face !== nothing
            refimg = ARGB32.(map(x -> ARGB32(1.0, 0.0, 0.0, 1.0), textinit))
            renderstring!(refimg, string(DateTime(2001)), face, pixelsize, timepos...;
                          fcolor=ARGB32(1.0, 1.0, 1.0, 1.0), bcolor=ARGB32(0.0, 0.0, 0.0, 1.0))
            textconfig=TextConfig(; font=font, timepixels=pixelsize, namepixels=pixelsize, bcolor=ARGB32(0))
            proc = ColorProcessor(zerocolor=ARGB32(1.0, 0.0, 0.0, 1.0), textconfig=textconfig)
            output = NoDisplayImageOutput((t=textinit,); tspan=1:1, processor=proc, store=true)
            simdata = SimData(extent(output), Ruleset())
            img = grid2image(proc, output, simdata, textinit, 1, DateTime(2001), nothing);
            @test img == refimg
        end
    end
    
end

@testset "SparseOptInspector" begin
    init =  Bool[
             0 0 0 0 0 0 0
             0 0 0 0 1 1 1
             0 0 0 0 0 0 1
             0 0 0 0 0 1 0
             0 0 0 0 0 0 0
             0 0 0 0 0 0 0
            ]
    ruleset = Ruleset(;
        rules=(Life(),),
        timestep=Day(1),
        overflow=WrapOverflow(),
        opt=SparseOpt(),
    )
    proc = SparseOptInspector()
    output = NoDisplayImageOutput(init; 
        tspan=Date(2001, 1, 1):Day(1):Date(2001, 1, 5), 
        processor=proc, minval=0.0, maxval=1.0, store=true
    )

    @test minval(output) === 0.0
    @test maxval(output) === 1.0
    @test processor(output) == SparseOptInspector()
    @test isstored(output) == true

    global images = []
    sim!(output, ruleset)
    w, y, c = ARGB32(1), ARGB32(.0, .0, .5), ARGB32(.5, .5, .5)
    @test_broken images[1] == [
             y y y y y y y
             y y y c w w w
             y y y c c c w
             y y y y y w c
             y y y y y c c
             y y y y y y y
            ]

end

@testset "LayoutProcessor" begin
    init = [8.0 10.0;
            0.0  5.0]
    z0 = ARGB32(1, 0, 0)
    grey = ColorProcessor(zerocolor=z0)
    leo = ColorProcessor(scheme=leonardo, zerocolor=z0)
    multiinit = (a = init, b = 2init)
    proc = LayoutProcessor([:a, nothing, :b], (grey, leo), nothing)
    output = NoDisplayImageOutput(init; tspan=1:1, processor=proc, minval=(0, 0), maxval=(10, 20), store=true)
    @test minval(output) === (0, 0)
    @test maxval(output) === (10, 20)
    @test processor(output) === proc
    @test isstored(output) == true
    simdata = SimData(extent(output), Ruleset(Life()))

    # Test image is joined from :a, nothing, :b
    @test grid2image(output, simdata, multiinit, 1, 1) ==
        [ARGB32(0.8, 0.8, 0.8) ARGB32(1.0, 1.0, 1.0)
         ARGB32(1.0, 0.0, 0.0) ARGB32(0.5, 0.5, 0.5)
         ARGB32(0.0, 0.0, 0.0) ARGB32(0.0, 0.0, 0.0)
         ARGB32(0.0, 0.0, 0.0) ARGB32(0.0, 0.0, 0.0)
         l08                  l1
         z0                   l05                 ]

    @testset "text captions" begin
        timepixels = 20
        timepos = 2timepixels, timepixels
        textinit = (a=zeros(200, 200), b=zeros(200, 200))
        font = "arial"
        face = findfont(font)
        if face === nothing
            font = "cantarell"
            face = findfont(font)
        end
        if face !== nothing
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
            textconfig = TextConfig(; font=font, timepixels=timepixels, namepixels=namepixels, bcolor=ARGB32(0))
            proc = LayoutProcessor([:a, nothing, :b], (grey, leo), textconfig)
            output = NoDisplayImageOutput(
                 textinit; tspan=1:10, processor=proc, store=true, 
                 minval=(0, 0), maxval=(1, 1)
            )
            simdata = SimData(extent(output), Ruleset())
            img = grid2image(output, simdata, textinit, 1, DateTime(2001));
            @test img == refimg
        end
    end

end

@testset "ThreeColorProcessor" begin
    mask = Bool[1 1 1 1 0]
    multiinit = (a=[5.0 5.0  4.0  4.0   5.0],
                 b=[0.1 0.2  0.0  0.0   4.0],
                 c=[5.0 5.0 10.0  5.0   0.6],
                 d=[9.0 0.0 15.0 50.0 -10.0])

    proc = ThreeColorProcessor(colors=(Green(), Red(), Blue(), nothing), zerocolor=0.9, maskcolor=0.8)
    @test proc.colors === (Green(), Red(), Blue(), nothing)
    output = NoDisplayImageOutput(multiinit; 
        mask=mask, tspan=1:1, processor=proc, 
        minval=(4, 0, 5, 0), maxval=(6, 1, 10, 1), store=true
    )
    @test minval(output) === (4, 0, 5, 0)
    @test maxval(output) === (6, 1, 10, 1)
    @test processor(output) === proc
    # Test image is combined from red and green overlays
    simdata = SimData(extent(output), Ruleset(Life()))
    @test grid2image(processor(output), output, simdata, multiinit, 1, 1) ==
        [ARGB32(0.1, 0.5, 0.0) ARGB32(0.2, 0.5, 0.0) ARGB32(0.0, 0.0, 1.0) ARGB32(0.9, 0.9, 0.9) ARGB32(0.8, 0.8, 0.8)]
end
