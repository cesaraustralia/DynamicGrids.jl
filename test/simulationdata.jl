using DynamicGrids, Test, Dates
using DynamicGrids: initdata!, data, init, mask, radius, overflow, source, 
    dest, sourcestatus, deststatus, localstatus, buffers, gridsize,
    ruleset, grids, starttime, currenttime, currentframe, grids, SimData

inita = [0 1 1
         0 1 1]
initb = [2 2 2
         2 2 2]
initab = (a=inita, b=initb)

rs = Ruleset(Life(read=:a, write=:a))
tstart = Day(10)
nreps = 2

simdata = initdata!(nothing, rs, initab, tstart, nothing)
@test simdata isa SimData
@test ruleset(simdata) === rs
@test starttime(simdata) === tstart
@test currentframe(simdata) === 1
@test currenttime(simdata) === tstart
@test radius(ruleset(simdata)) === (a=1,)
gs = grids(simdata)

@test parent(source(gs[:a])) == parent(dest(gs[:a])) ==
    [0 0 0 0 0
     0 0 1 1 0
     0 0 1 1 0
     0 0 0 0 0]
# This seems like too much outer padding
# - should there be that one row and colum extra?
@test sourcestatus(gs[:a]) == deststatus(gs[:a]) == 
    [0 1 0 0
     0 1 0 0
     0 0 0 0]
@test buffers(gs[:a]) == 
    [[0 0 0; 0 0 0; 0 0 0], [0 0 0; 0 0 0; 0 0 0]]

@test parent(source(gs[:b])) == parent(dest(gs[:b])) == 
    [2 2 2
     2 2 2]
@test sourcestatus(gs[:b]) == deststatus(gs[:b]) == true
@test buffers(gs[:b]) === nothing


initdata!(simdata, rs, initab, tstart, nothing)

simdata = initdata!(nothing, rs, initab, tstart, nreps)
@test simdata isa Vector{<:SimData}
initdata!(simdata, rs, initab, tstart, nreps)

