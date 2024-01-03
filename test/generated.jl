using DynamicGrids, Test
using DynamicGrids: SimData, GridData, WriteMode, Extent,
    _getreadgrids, _getwritegrids, _readcell, _writecell!, grids, source, dest

rule = Cell{Tuple{:c,:a,:b},Tuple{:a,:c}}(identity)
init = (a=fill(1, 4, 4), b=fill(2, 4, 4), c=fill(3, 4, 4))
simdata = SimData(Extent(;init=init, tspan=1:1), Ruleset(rule))

@testset "_getreadgrids gets read grids for a Rule" begin
    rkeys, rgrids = _getreadgrids(rule, simdata)
    @test rkeys === (Val(:c), Val(:a), Val(:b))
    @test rgrids === (simdata[:c], simdata[:a], simdata[:b])
end

@testset "_getwritegrids gets write grids for a Rule" begin
    wkeys, wgrids = _getwritegrids(WriteMode, rule, simdata)
    @test wkeys === (Val(:a), Val(:c))
    @test wgrids === map(GridData{WriteMode}, (simdata[:a], simdata[:c]))
end

@testset "_readcell read from specified grids" begin
    @test _readcell(simdata, Val(:a), 1, 1) == 1
    @test _readcell(simdata, Val(:b), 1, 1) == 2
    @test _readcell(simdata, Val(:c), 1, 1) == 3
    @test _readcell(simdata, (Val(:c), Val(:a), Val(:b)), 1, 1) == (c=3, a=1, b=2)
    @test _readcell(simdata, (Val(:a), Val(:c)), 1, 1) == (a=1, c=3)
end

@testset "_writecell writes to source for CellRule" begin
    simdata = SimData(Extent(;init=init, tspan=1:1), Ruleset(rule))
    _writecell!(simdata, Val(CellRule), (Val(:c), Val(:a), Val(:b)), (8, 6, 7), 1, 2)
    @test map(g -> source(g)[1, 2], grids(simdata)) == (a=6, b=7, c=8)
    @test map(g -> dest(g)[1, 2], grids(simdata)) == (a=1, b=2, c=3)
    simdata = SimData(Extent(;init=init, tspan=1:1), Ruleset(rule))
    _writecell!(simdata, Val(CellRule), Val(:c), 99, 4, 3)
    @test source(simdata[:c])[4, 3] == 99
    @test dest(simdata[:c])[4, 3] == 3
end

@testset "_writecell writes to dest for other Rules" begin
    simdata = SimData(Extent(;init=init, tspan=1:1), Ruleset(rule))
    _writecell!(simdata, Val(Rule), (Val(:b), Val(:a)), (11, 10), 4, 4)
    @test map(g -> source(g)[4, 4], grids(simdata)) == (a=1, b=2, c=3)
    @test map(g -> dest(g)[4, 4], grids(simdata)) == (a=10, b=11, c=3)
    simdata = SimData(Extent(;init=init, tspan=1:1), Ruleset(rule))
    _writecell!(simdata, Val(Rule), Val(:c), 99, 4, 3)
    @test source(simdata[:c])[4, 3] == 3
    @test dest(simdata[:c])[4, 3] == 99
end

nothing
