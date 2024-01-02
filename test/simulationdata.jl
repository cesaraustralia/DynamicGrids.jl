using DynamicGrids, Test, Dates
using DynamicGrids: init, mask, boundary, source, dest, 
    sourcestatus, deststatus, gridsize, ruleset, grids, SimData, Extent,
    _updatetime, GridData, SwitchMode, WriteMode, tspan, extent, optdata

inita = [0 1 1
         0 1 1]
initb = [2 2 2
         2 2 2]
initab = (a=inita, b=initb)

life = Life{:a,:a}()
tspan_ = DateTime(2001):Day(1):DateTime(2001, 2)

@testset "SimData" begin
    rs = Ruleset(life, timestep=Day(1); opt=SparseOpt());

    ext = Extent(; init=initab, tspan=tspan_)
    simdata = SimData(ext, rs)

    @test simdata isa SimData
    @test init(simdata) == initab
    @test mask(simdata) === nothing
    @test ruleset(simdata) === StaticRuleset(rs)
    @test tspan(simdata) === tspan_
    @test currentframe(simdata) === 1
    @test first(simdata) === simdata[:a]
    @test last(simdata) === simdata[:b]
    @test boundary(simdata) === Remove()
    @test gridsize(simdata) == (2, 3)
    updated = _updatetime(simdata, 2)
    @test currenttimestep(simdata) == Millisecond(86400000)

    gs = grids(simdata)
    grida = gs[:a]
    gridb = gs[:b]

    @test parent(source(grida)) ==
        [0 0 0 0 0
         0 0 1 1 0
         0 0 1 1 0
         # 0 0 0 0 0
         # 0 0 0 0 0
         0 0 0 0 0]

    wgrida = GridData{SwitchMode}(grida)
    @test parent(source(grida)) === parent(source(wgrida))
    @test parent(dest(grida)) === parent(dest(wgrida))

    @test grida == wgrida ==
        [0 1 1 
         0 1 1]

    # Status isn't updated in the constructor now...
    @test_broken sourcestatus(grida) == deststatus(grida) == 
        [0 1 0 0
         0 1 0 0
         # 0 0 0 0
         0 0 0 0]

    @test parent(source(gridb)) == parent(dest(gridb)) == 
        [2 2 2
         2 2 2]
    @test optdata(gridb) == optdata(gridb) == nothing

    @test firstindex(grida) == 1
    @test lastindex(grida) == 6
    @test gridsize(grida) == (2, 3) == size(grida) == (2, 3)
    @test axes(grida) == (1:2, 1:3)
    @test ndims(grida) == 2
    @test eltype(grida) == Int

    output = ArrayOutput(initab; tspan=tspan_)
    SimData(simdata, output, extent(output), rs)
end

@testset "SimData with :_default_" begin
    initx = [1 0]
    rs = Ruleset(Life())
    output = ArrayOutput((_default_=initx,); tspan=tspan_)
    simdata = SimData(output, rs)
    simdata2 = SimData(simdata, output, extent(output), rs)
    @test keys(simdata2) == (:_default_,)
    @test DynamicGrids.ruleset(simdata2) == DynamicGrids.StaticRuleset(rs)
    @test DynamicGrids.init(simdata2)[:_default_] == [1 0]
    @test DynamicGrids.source(simdata2[:_default_]) == [0 0 0 0; 0 1 0 0; 0 0 0 0]
end
