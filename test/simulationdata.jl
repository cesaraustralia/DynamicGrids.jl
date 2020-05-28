using DynamicGrids, OffsetArrays, Test, Dates
using DynamicGrids: initdata!, data, init, mask, radius, overflow, source, 
    dest, sourcestatus, deststatus, localstatus, gridsize,
    ruleset, grids, starttime, currentframe, grids, SimData, 
    updatetime, ismasked, currenttimestep, WritableGridData

inita = [0 1 1
         0 1 1]
initb = [2 2 2
         2 2 2]
initab = (a=inita, b=initb)

life = Life(read=:a, write=:a);
rs = Ruleset(life, timestep=Day(1))
tspan = DateTime(2001):Day(1):DateTime(2001, 2)

@testset "initdata!" begin
    simdata = initdata!(nothing, initab, nothing, rs, tspan, nothing)
    @test simdata isa SimData
    @test init(simdata) == initab
    @test ruleset(simdata) === rs
    @test DynamicGrids.tspan(simdata) === tspan
    @test currentframe(simdata) === 1
    @test first(simdata) === simdata[:a]
    @test last(simdata) === simdata[:b]
    @test overflow(simdata) === RemoveOverflow()
    @test gridsize(simdata) == (2, 3)
    updated = updatetime(simdata, 2)
    @test currenttimestep(simdata) == Millisecond(86400000)

    gs = grids(simdata)
    grida = gs[:a]
    gridb = gs[:b]

    @test parent(source(grida)) == parent(dest(grida)) ==
        [0 0 0 0 0
         0 0 1 1 0
         0 0 1 1 0
         0 0 0 0 0]

    wgrida = WritableGridData(grida)
    @test parent(grida) == parent(source(grida)) == parent(source(wgrida))
    @test parent(wgrida) === parent(dest(grida)) === parent(dest(wgrida))

    # This seems like too much outer padding
    # - should there be that one row and colum extra?
    @test sourcestatus(grida) == deststatus(grida) == 
        [0 1 0 0
         0 1 0 0
         0 0 0 0]

    @test parent(source(gridb)) == parent(dest(gridb)) == 
        [2 2 2
         2 2 2]
    @test sourcestatus(gridb) == deststatus(gridb) == true

    @test firstindex(grida) == 1
    @test lastindex(grida) == 20
    @test size(grida) == (4, 5)
    @test axes(grida) == (0:3, 0:4)
    @test ndims(grida) == 2
    @test eltype(grida) == Int
    @test ismasked(grida, 1, 1) == false

    initdata!(simdata, initab, nothing, rs, tspan, nothing)
end

@testset "initdata! with :_default_" begin
    initx = [1 0]
    rs = Ruleset(Life())
    simdata = initdata!(nothing, initx, nothing, rs, tspan, nothing)
    simdata2 = initdata!(simdata, initx, nothing, rs, tspan, nothing)
    @test keys(simdata2) == (:_default_,)
    @test DynamicGrids.ruleset(simdata2) === rs
    @test DynamicGrids.init(simdata2[:_default_]) == [1 0]
    @test DynamicGrids.source(simdata2[:_default_]) == 
        OffsetArray([0 0 0 0
                     0 1 0 0
                     0 0 0 0], (0:2, 0:3))
end

@testset "initdata! with replicates" begin
    nreps = 2
    simdata = initdata!(nothing, initab, nothing, rs, tspan, nreps)
    @test simdata isa Vector{<:SimData}
    @test all(DynamicGrids.ruleset.(simdata) .== Ref(rs))
    @test all(map(DynamicGrids.tspan, simdata) .== Ref(tspan))
    @test all(keys.(DynamicGrids.grids.(simdata)) .== Ref(keys(initab)))
    simdata2 = initdata!(simdata, initab, nothing, rs, tspan, nreps)
end

# TODO more comprehensively unit test? a lot of this is
# relying on integration testing.
