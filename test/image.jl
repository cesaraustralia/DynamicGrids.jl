using DynamicGrids, Dates, Test, Colors, ColorSchemes, FileIO
using FreeTypeAbstraction
using DynamicGrids: render!, renderer, minval, maxval, normalise, SimData, NoDisplayImageOutput,
    isstored, isasync, initialise!, finalise!, maybesleep, fps, settimestamp!, timestamp, textconfig,
    tspan, setfps!, frames, isshowable, showframe, to_rgb, scale, Extent, extent, 
    _autokeys, _autolayout
using ColorSchemes: leonardo

@testset "to_rgb" begin
    @test to_rgb(0.5) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test to_rgb((0.5, 0.5, 0.5)) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test to_rgb((0.5, 0.5, 0.5, 1.0)) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test to_rgb(RGB(0.5, 0.5, 0.5)) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test to_rgb(ARGB32(0.5, 0.5, 0.5)) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test to_rgb(Greyscale(), 0.5) === ARGB32(0.5, 0.5, 0.5, 1.0)
    @test to_rgb(ObjectScheme(), 0.5) === ARGB32(0.5, 0.5, 0.5, 1.0)
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

DynamicGrids.showimage(image, o::NoDisplayImageOutput) = begin
    push!(images, image)
    image
end

@testset "basic ImageOutput" begin
    init_ = [8.0 10.0;
             NaN  5.0]
    output = NoDisplayImageOutput(init_; tspan=1:1, maxval=40.0, text=nothing)

    @test all(parent(output)[1] .=== init_)
    @test minval(output) === 0
    @test maxval(output) === 40.0
    @test textconfig(output) === nothing
    @test renderer(output).scheme == ObjectScheme()
    @test isasync(output) == false
    @test isstored(output) == false
    @test maybesleep(output, 1.0) === nothing
    @test timestamp(output) === 0.0
    pre = time()
    settimestamp!(output, 1)
    @test timestamp(output) > pre
    @test length(output) == 1
    push!(output, 2init_)
    @test length(output) == 2
    @test all(output[2] .=== 2init_)
    @test tspan(output) == 1:1
    @test fps(output) === 25.0
    @test setfps!(output, 1000.0) === 1000.0
    @test fps(output) === 1000.0
    output[1] = 5init_
    @test all(frames(output)[1] .=== 5init_)
    @test isshowable(output, 1)

    rndr = Image()
    output = NoDisplayImageOutput(init_; 
        tspan=1:10, maxval=40.0, renderer=rndr, text=nothing
    )
    simdata = SimData(output, Ruleset(Life()))
    z0 = DynamicGrids.ZEROCOL
    ref = [ARGB32(0.2, 0.2, 0.2) ARGB32(0.25, 0.25, 0.25)
           z0                    ARGB32(0.125, 0.125, 0.125)]
    @test showframe(output, simdata) == ref
    savegif("test.gif", output)
    gif = load("test.gif")
    @test gif == RGB.(ref)
    rm("test.gif")
end

@testset "Renderer" begin

    @testset "auto render layout" begin
        @test _autokeys((a=[0], b=[0], c=[0])) == (:a, :b, :c)
        @test _autokeys((a=[[0,0]], b=[1], c=[[3,4]])) == (:a=>1, :a=>2, :b, :c=>1, :c=>2)
        @test _autolayout([0]) == reshape(Any[1], 1, 1)
        @test _autolayout((a=[0], b=[0], c=[0])) == Any[:a :b :c]
        @testset "Empty layout cells are filled with nothing" begin
            @test _autolayout((a=[[0,0]], b=[1], c=[[3,4]])) == Any[:a=>1 :b :c=>2; :a=>2 :c=>1 nothing]
        end
    end

    init_ = [8.0 10.0;
             0.0  5.0]
    mask_ = Bool[0 1;
                 1 1]
    rndr = Image(zerocolor=(1.0, 0.0, 0.0), maskcolor=(0.1, 0.1, 0.1))
    ic = DynamicGrids.ImageConfig(init_; renderer=rndr, textconfig=nothing)
    @test ic.renderer === rndr
    output = NoDisplayImageOutput((a=init_,); 
        tspan=DateTime(2001):Year(1):DateTime(2010), mask=mask_,
        renderer=rndr, text=nothing, minval=0.0, maxval=10.0, store=true
    )
    @test renderer(output) === output.imageconfig.renderer === rndr
    @test minval(output) === 0.0
    @test maxval(output) === 10.0
    @test renderer(output).zerocolor == Image(zerocolor=(1.0, 0.0, 0.0)).zerocolor
    @test isstored(output) == true
    simdata = SimData(output, Ruleset(Life()))

    # Test level normalisation
    normed = normalise.(output[1][:a], minval(output), maxval(output))
    @test normed == [0.8 1.0
                     0.0 0.5]

    # Test greyscale Image conversion
    img = render!(output, simdata)
    @test img == [ARGB32(0.1, 0.1, 0.1, 1.0) ARGB32(1.0, 1.0, 1.0, 1.0)
                  ARGB32(1.0, 0.0, 0.0, 1.0) ARGB32(0.5, 0.5, 0.5, 1.0)]

    output = NoDisplayImageOutput((a=init_,); 
        tspan=DateTime(2001):Year(1):DateTime(2010), mask=mask_,
        renderer=Image(; scheme=leonardo), text=nothing,
        minval=0.0, maxval=10.0, store=true
    )
    img = render!(output, simdata)
    @test img == [DynamicGrids.MASKCOL l1
                  DynamicGrids.ZEROCOL l05]
    z0 = ARGB32(1, 0, 0)
    output = NoDisplayImageOutput((a=init_,); 
        tspan=DateTime(2001):Year(1):DateTime(2010), mask=mask_,
        renderer = Image(scheme=leonardo, zerocolor=z0), text=nothing,
        minval=0.0, maxval=10.0, store=true
    )
    img = render!(output, simdata)
    @test img == [DynamicGrids.MASKCOL l1
                  z0 l05]

    @testset "text captions" begin
        pixelsize = 20
        timepos = 2pixelsize, pixelsize
        textinit = zeros(200, 200)
        font = "arial"
        face = findfont(font)
        # Swap fonts on linux
        if face === nothing
            font = "sans-serif"
            face = findfont(font)
        end
        if face !== nothing
            refimg = ARGB32.(map(x -> ARGB32(1.0, 0.0, 0.0, 1.0), textinit))
            renderstring!(refimg, string(DateTime(2001)), face, pixelsize, timepos...;
                          fcolor=ARGB32(1.0, 1.0, 1.0, 1.0), bcolor=ARGB32(0.0, 0.0, 0.0, 1.0))
            textconfig=TextConfig(; font=font, timepixels=pixelsize, namepixels=pixelsize, bcolor=ARGB32(0))
            output = NoDisplayImageOutput(textinit; 
                tspan=DateTime(2001):Year(1):DateTime(2001),
                renderer=Image(zerocolor=ARGB32(1.0, 0.0, 0.0, 1.0)), 
                text=textconfig, store=true,
            )
            simdata = SimData(output, Ruleset())
            img = render!(output, simdata);
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
    ruleset = Ruleset(Life();
        timestep=Day(1),
        boundary=Wrap(),
        opt=SparseOpt(),
    )
    rndr = SparseOptInspector()
    output = NoDisplayImageOutput(init; 
        tspan=Date(2001, 1, 1):Day(1):Date(2001, 1, 5), 
        renderer=rndr, minval=0.0, maxval=1.0, store=true
    )

    @test minval(output) === 0.0
    @test maxval(output) === 1.0
    @test renderer(output) == SparseOptInspector()
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

@testset "Layout Renderer" begin
    init = [8.0 10.0;
            0.0  5.0]
    z0 = DynamicGrids.ZEROCOL
    grey = Greyscale()
    multiinit = (a=init, b=2init)
    rndr = Layout([:a nothing :b], [grey nothing leonardo])
    @test DynamicGrids.imagesize(rndr, init, 1:1) == (2, 6)

    output = NoDisplayImageOutput(multiinit; 
        tspan=DateTime(2001):Year(1):DateTime(2002), 
        renderer=rndr, 
        text=nothing,
        minval=[0 nothing 0], maxval=[10 nothing 20], 
        store=true
    )
    @test minval(output) == [0 nothing 0]
    @test maxval(output) == [10 nothing 20]
    @test renderer(output) === rndr
    @test isstored(output) == true
    simdata = SimData(output, Ruleset(Life()))

    # Test image is joined from :a, nothing, :b
    @test render!(output, simdata) ==
        [ARGB32(0.8, 0.8, 0.8, 1.0) ARGB32(1.0, 1.0, 1.0, 1.0) ARGB32(0.0) ARGB32(0.0) l08 l1
         z0                         ARGB32(0.5, 0.5, 0.5, 1.0) ARGB32(0.0) ARGB32(0.0) z0  l05]

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
            # Set up refernce image
            refimg = cat(fill(z0, 200, 200), 
                         fill(ARGB32(0), 200, 200), 
                         fill(z0, 200, 200); dims=1)
            renderstring!(refimg, string(DateTime(2001)), face, timepixels, timepos...;
                          fcolor=ARGB32(RGB(1.0), 1.0), bcolor=ARGB32(RGB(0.0), 1.0))
            namepixels = 15
            nameposa = 3timepixels + namepixels, timepixels
            renderstring!(refimg, "a", face, namepixels, nameposa...;
                          fcolor=ARGB32(RGB(1.0), 1.0), bcolor=ARGB32(RGB(0.0), 1.0))
            nameposb = 3timepixels + namepixels + 400, timepixels
            renderstring!(refimg, "b", face, namepixels, nameposb...;
                          fcolor=ARGB32(RGB(1.0), 1.0), bcolor=ARGB32(RGB(0.0), 1.0))
            textconf = TextConfig(; font=font, timepixels=timepixels, namepixels=namepixels, bcolor=ARGB32(0))

            # Build renderer
            output = NoDisplayImageOutput(textinit; 
                 tspan=DateTime(2001):Year(1):DateTime(2001), 
                 text=textconf,
                 store=true, 
                 layout=[:a, nothing, :b],
                 scheme=[grey, nothing, leonardo],
                 minval=[0, nothing, 0], 
                 maxval=[1, nothing, 1]
            )

            output.imageconfig.renderer

            simdata = SimData(output, Ruleset())
            img = render!(output, simdata);
            @test img == refimg
        end
    end
    @testset "errors" begin
        output = NoDisplayImageOutput(multiinit; 
            tspan=1:10, renderer=rndr, 
            minval=[0, 0, 0], 
            maxval=[10, 20], 
        )
        simdata = SimData(output, Ruleset(Life()))
        @test_throws ArgumentError render!(output, simdata)
        broken_rndr = Layout([:d, :c], (grey, leonardo))
        output = NoDisplayImageOutput(multiinit; 
            tspan=1:10, renderer=broken_rndr, text=nothing, minval=[0, 0], maxval=[10, 20],
        )
        simdata = SimData(output, Ruleset(Life()))
        @test_throws ArgumentError render!(output, simdata)
        @test_throws ArgumentError TextConfig(; font="not_a_font")
        @test_throws ArgumentError TextConfig(; font=:not_a_string)
    end
    @testset "Layout is the default for NamedTuple of grids" begin
        output = NoDisplayImageOutput(multiinit; tspan=1:10)
        @test renderer(output) isa Layout
        @test DynamicGrids.imagesize(renderer(output), multiinit, 1:1) == (2, 4)
    end
end

@testset "simulation savegif from ArrayOutput" begin
    init_ = Bool[
        0 0 0 0 0
        0 0 1 1 1
        0 0 0 0 1
        0 0 0 1 0
    ]
    ig = Image(zerocolor=RGB(0.0))
    output = ArrayOutput(init_; tspan=1:10)
    @test minval(output) == 0
    @test maxval(output) == 1
    @test renderer(output) isa Image
    @test fps(output) === nothing
    sim!(output, Life())
    savegif("test2.gif", output; renderer=Image(zerocolor=RGB(0.0)), text=nothing)
    gif = load("test2.gif")
    @test gif[:, :, 1] == RGB.(cat(output...; dims=3))[:, :, 1]
    rm("test2.gif")
end
