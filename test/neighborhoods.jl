using DynamicGrids, Setfield, Test
import DynamicGrids: neighbors, sumneighbors, SimData, Extent, radius, neighbors,
       mapsetneighbor!, neighborhood, WritableGridData, dest, hoodsize, neighborhoodkey,
       allocbuffer, allocbuffers, buffer, coords

@testset "allocbuffers" begin
    @test allocbuffer(Bool[1 0], 1) == Bool[0 0 0
                                            0 0 0
                                            0 0 0]
    @test allocbuffer(Int[1 0], 2) == [0 0 0 0 0
                                       0 0 0 0 0
                                       0 0 0 0 0
                                       0 0 0 0 0
                                       0 0 0 0 0]
    @test allocbuffer([1.0, 2.0], Moore{4}()) == zeros(Float64, 9, 9)
    @test allocbuffers(Bool[1 0], 2) == Tuple(zeros(Bool, 5, 5) for i in 1:4)
    @test allocbuffers([1 0], Moore{3}()) == Tuple(zeros(Int, 7, 7) for i in 1:6)
end

@testset "neighbors" begin
    init = [0 0 0 1 1 1
            1 0 1 1 0 1
            0 1 1 1 1 1
            0 1 0 0 1 0
            0 0 0 0 1 1
            0 1 0 1 1 0]

    moore = Moore{1}(init[1:3, 1:3])

    @test buffer(moore) == init[1:3, 1:3]
    multibuffer = Moore{1}(zeros(Int, 3, 3))
    @test buffer(multibuffer) == zeros(Int, 3, 3)
    @test hoodsize(moore) == 3
    @test moore[2, 2] == 0
    @test length(moore) == 8
    @test eltype(moore) == Int
    @test neighbors(moore) isa Base.Generator
    @test collect(neighbors(moore)) == [0, 1, 0, 0, 1, 0, 1, 1]
    @test sum(neighbors(moore)) == 4

    vonneumann = VonNeumann(1, init[1:3, 1:3])
    @test coords(vonneumann) == [(0, -1), (-1, 0), (1, 0), (0, 1)]
    @test buffer(vonneumann) == init[1:3, 1:3]
    @test hoodsize(vonneumann) == 3
    @test vonneumann[2, 1] == 1
    @test length(vonneumann) == 4
    @test eltype(vonneumann) == Int
    @test neighbors(vonneumann) isa Base.Generator
    @test collect(neighbors(vonneumann)) == [1, 0, 1, 1]
    @test sum(neighbors(vonneumann)) == 3
    vonneumann2 = VonNeumann(2)
    @test coords(vonneumann2) == 
        [(0, -2), (-1, -1), (0, -1), (1, -1), 
         (-2 , 0), (-1, 0), (1, 0), (2, 0), 
         (-1, 1), (0, 1), (1, 1), (0, 2)]

    buf = [0 0 0
           0 1 0
           0 0 0]
    @test sum(Moore{1}(buf)) == 0
    @test sum(VonNeumann(1, buf)) == 0

    buf = [1 1 1
           1 0 1
           1 1 1]
    @test sum(Moore{1}(buf)) == 8
    @test sum(VonNeumann(1, buf)) == 4

    buf = [1 1 1
           0 0 1
           0 0 1]
    @test sum(Moore(1, buf)) == 5
    @test sum(VonNeumann(1, buf)) == 2

    buf = [0 1 0 0 1
           0 0 1 0 0
           0 0 0 1 1
           0 0 1 0 1
           1 0 1 0 1]
    state = buf[3, 3]
    custom1 = Positional(((-1,-1), (2,-2), (2,2), (-1,2), (0,0)), buf)
    custom2 = Positional(((-1,-1), (0,-1), (1,-1), (2,-1), (0,0)), buf)
    layered = LayeredPositional(
        (Positional((-1,1), (-2,2)), Positional((1,2), (2,2))), buf)

    @test neighbors(custom1) isa Base.Generator
    @test collect(neighbors(custom1)) == [0, 1, 1, 0, 0]

    @test sum(custom1) == 2
    @test sum(custom2) == 0
    @test sum(layered) == (1, 2)

    @testset "neighbors works on rule" begin
        rule = Life(;neighborhood=Moore{1}([0 1 1; 0 0 0; 1 1 1]))
        @test sum(neighbors(rule)) == 5
    end
end

struct TestNeighborhoodRule{R,W,N} <: NeighborhoodRule{R,W}
    neighborhood::N
end
DynamicGrids.applyrule(data, rule::TestNeighborhoodRule, state, index) =
    state

struct TestManualNeighborhoodRule{R,W,N} <: ManualNeighborhoodRule{R,W}
    neighborhood::N
end
DynamicGrids.applyrule!(data, rule::TestManualNeighborhoodRule{R,Tuple{W1,}}, state, index
                       ) where {R,W1} =
    data[W1][index...] = state[1]



@testset "neighborhood rules" begin
    ruleA = TestManualNeighborhoodRule{:a,:a}(Moore{3}())
    ruleB = TestManualNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}())
    @test neighbors(ruleA) isa Base.Generator
    @test neighborhood(ruleA) == Moore{3}()
    @test neighborhood(ruleB) == Moore{2}()
    @test neighborhoodkey(ruleA) == :a
    @test neighborhoodkey(ruleB) == :b

    ruleA = TestNeighborhoodRule{:a,:a}(Moore{3}())
    ruleB = TestNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}())
    @test neighbors(ruleA) isa Base.Generator
    @test neighborhood(ruleA) == Moore{3}()
    @test neighborhood(ruleB) == Moore{2}()
    @test neighborhoodkey(ruleA) == :a
    @test neighborhoodkey(ruleB) == :b
end

@testset "radius" begin
    init = (a=[1. 2.], b=[10. 11.])
    ruleA = TestNeighborhoodRule{:a,:a}(Moore{3}())
    ruleB = TestManualNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}())
    ruleset = Ruleset(ruleA, ruleB)
    @test radius(ruleA) == 3
    @test radius(ruleB) == 2
    @testset "ruleset returns max radii of all rule" begin
        @test radius(ruleset) == (a=3, b=2)
    end
    @test radius(Ruleset()) == NamedTuple()

    output = ArrayOutput(init; tspan=1:3)
    sim!(output, ruleset)
    # TODO make sure 2 radii can coexist
end

DynamicGrids.setneighbor!(data, hood, rule::TestManualNeighborhoodRule,
             state, hood_index, dest_index) = begin
    data[dest_index...] += state
    state
end

@testset "mapsetneighbor!" begin
    init = [0 1 2 3 4 5
            0 1 2 3 4 5
            0 1 2 3 4 5
            0 1 2 3 4 5
            0 1 2 3 4 5
            0 1 2 3 4 5]

    hood = Moore(1)
    rule = TestManualNeighborhoodRule{:a,:a}(hood)
    ruleset = Ruleset(rule)
    extent = Extent((_default_=init,), nothing, 1:1, nothing)
    simdata = SimData(extent, ruleset)
    state = 5
    index = (3, 3)
    @test mapsetneighbor!(WritableGridData(first(simdata)), hood, rule, state, index) == 40
    @test dest(first(simdata)) ==
        [0 1 2 3 4 5
         0 6 7 8 4 5
         0 6 2 8 4 5
         0 6 7 8 4 5
         0 1 2 3 4 5
         0 1 2 3 4 5]

    hood = Positional(((-1, -1), (1, 1)))
    rule = TestManualNeighborhoodRule{:a,:a}(hood)
    ruleset = Ruleset(rule)
    extent = Extent((_default_=init,), nothing, 1:1, nothing)
    simdata = SimData(extent, ruleset)
    state = 1
    index = (5, 5)
    @test mapsetneighbor!(WritableGridData(first(simdata)), neighborhood(rule), rule, state, index) == 2
    @test dest(first(simdata)) ==
        [0 1 2 3 4 5
         0 1 2 3 4 5
         0 1 2 3 4 5
         0 1 2 4 4 5
         0 1 2 3 4 5
         0 1 2 3 4 6]


    hood = LayeredPositional(
        (Positional(((-1, -1), (1, 1))), Positional(((-2, -2), (2, 2)))),
        nothing,
    )
    rule = TestManualNeighborhoodRule{:a,:a}(hood)
    @test radius(rule) === 2
    ruleset = Ruleset(rule)
    extent = Extent((_default_=init,), nothing, 1:1, nothing)
    simdata = SimData(extent, ruleset)
    state = 1
    index = (3, 3)
    @test mapsetneighbor!(WritableGridData(first(simdata)), neighborhood(rule), rule, state, index) == (2, 2)
    @test dest(first(simdata)) ==
        [1 1 2 3 4 5
         0 2 2 3 4 5
         0 1 2 3 4 5
         0 1 2 4 4 5
         0 1 2 3 5 5
         0 1 2 3 4 5]
end

@testset "construction" begin
    hood = Positional(((-1, -1), (1, 1)))
    @set! hood.coords = ((-5, -5), (5, 5))
    @test hood.coords == ((-5, -5), (5, 5))

    hood = LayeredPositional(
        (Positional(((-1, -1), (1, 1))), Positional(((-2, -2), (2, 2)))),
        nothing,
    )
    @set! hood.layers = (Positional(((-3, -3), (3, 3))),)
    @test hood.layers == (Positional(((-3, -3), (3, 3))),)
end
