using DynamicGrids, Test, Dates
using DynamicGrids: initdata!, data, init, mask, radius, overflow, source, 
    dest, sourcestatus, deststatus, localstatus, buffers, gridsize,
    ruleset, grids, starttime, currenttime, currentframe, grids, SimData, 
    updatetime, ismasked

inita = [0 1 1
         0 1 1]
initb = [2 2 2
         2 2 2]
initab = (a=inita, b=initb)

rs = Ruleset(Life(read=:a, write=:a), timestep=Day(1))
tstart = DateTime(2001)
nreps = 2

simdata = initdata!(nothing, rs, initab, tstart, nothing)
@test simdata isa SimData
@test init(simdata) == initab
@test ruleset(simdata) === rs
@test starttime(simdata) === tstart
@test currentframe(simdata) === 1
@test currenttime(simdata) === tstart
@test first(simdata) === simdata[:a]
@test last(simdata) === simdata[:b]
@test overflow(simdata) === RemoveOverflow()
updated = updatetime(simdata, 2)
@test currenttime(updated) === tstart + Day(1)

gs = grids(simdata)
grida = gs[:a]
gridb = gs[:b]

@test parent(source(grida)) == parent(dest(grida)) ==
    [0 0 0 0 0
     0 0 1 1 0
     0 0 1 1 0
     0 0 0 0 0]
# This seems like too much outer padding
# - should there be that one row and colum extra?
@test sourcestatus(grida) == deststatus(grida) == 
    [0 1 0 0
     0 1 0 0
     0 0 0 0]
@test buffers(grida) == 
    [[0 0 0; 0 0 0; 0 0 0], [0 0 0; 0 0 0; 0 0 0]]

@test parent(source(gridb)) == parent(dest(gridb)) == 
    [2 2 2
     2 2 2]
@test sourcestatus(gridb) == deststatus(gridb) == true
@test buffers(gridb) === nothing

@test firstindex(grida) == 1
@test lastindex(grida) == 20
@test size(grida) == (4, 5)
@test ndims(grida) == 2
@test eltype(grida) == Int
@test ismasked(grida, 1, 1) == false

initdata!(simdata, rs, initab, tstart, nothing)

simdata = initdata!(nothing, rs, initab, tstart, nreps)
@test simdata isa Vector{<:SimData}
initdata!(simdata, rs, initab, tstart, nreps)

