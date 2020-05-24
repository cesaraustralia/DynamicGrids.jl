using DynamicGrids, Setfield, Test
import DynamicGrids: neighbors, sumneighbors, SimData, radius, neighbors,
       mapsetneighbor!, neighborhood, WritableGridData, dest, hoodsize, neighborhoodkey,
       allocbuffer, allocbuffers, buffer

@testset "allocbuffers" begin
    @test allocbuffer(Bool[1 0], 1) == Bool[0 0 0
                                            0 0 0
                                            0 0 0]
    @test allocbuffer(Int[1 0], 2) == [0 0 0 0 0
                                       0 0 0 0 0
                                       0 0 0 0 0
                                       0 0 0 0 0
                                       0 0 0 0 0]
    @test allocbuffer([1.0, 2.0], RadialNeighborhood{4}()) == zeros(Float64, 9, 9)
    @test allocbuffers(Bool[1 0], 2) == Tuple(zeros(Bool, 5, 5) for i in 1:4)
    @test allocbuffers([1 0], RadialNeighborhood{3}()) == Tuple(zeros(Int, 7, 7) for i in 1:6)
end

@testset "neighbors" begin
    init = [0 0 0 1 1 1
            1 0 1 1 0 1
            0 1 1 1 1 1
            0 1 0 0 1 0
            0 0 0 0 1 1
            0 1 0 1 1 0]

    moore = RadialNeighborhood{1}(init[1:3, 1:3])

    @test buffer(moore) == init[1:3, 1:3]
    multibuffer = RadialNeighborhood{1}((zeros(Int, 3, 3), ones(Int, 3, 4)))
    @test buffer(multibuffer) == zeros(Int, 3, 3)
    @test hoodsize(moore) == 3
    @test moore[2, 2] == 0
    @test length(moore) == 8
    @test eltype(moore) == Int
    @test neighbors(moore) isa Base.Generator
    @test collect(neighbors(moore)) == [0, 1, 0, 0, 1, 0, 1, 1]
    @test sum(neighbors(moore)) == 4

    vonneumann = VonNeumannNeighborhood(init[1:3, 1:3])
    @test buffer(vonneumann) == init[1:3, 1:3]
    @test hoodsize(vonneumann) == 3
    @test vonneumann[2, 1] == 1
    @test length(vonneumann) == 4
    @test eltype(vonneumann) == Int
    @test neighbors(vonneumann) isa Base.Generator
    @test collect(neighbors(vonneumann)) == [1, 0, 1, 1]
    @test sum(neighbors(vonneumann)) == 3

    buf = [0 0 0
           0 1 0
           0 0 0]
    @test sum(RadialNeighborhood{1}(buf)) == 0
    @test sum(VonNeumannNeighborhood(buf)) == 0

    buf = [1 1 1
           1 0 1
           1 1 1]
    @test sum(RadialNeighborhood{1}(buf)) == 8
    @test sum(VonNeumannNeighborhood(buf)) == 4

    buf = [1 1 1
           0 0 1
           0 0 1]
    @test sum(RadialNeighborhood{1}(buf)) == 5
    @test sum(VonNeumannNeighborhood(buf)) == 2

    buf = [0 1 0 0 1
           0 0 1 0 0
           0 0 0 1 1
           0 0 1 0 1
           1 0 1 0 1]
    state = buf[3, 3]
    custom1 = CustomNeighborhood(((-1,-1), (2,-2), (2,2), (-1,2), (0,0)), buf)
    custom2 = CustomNeighborhood(((-1,-1), (0,-1), (1,-1), (2,-1), (0,0)), buf)
    layered = LayeredCustomNeighborhood(
        (CustomNeighborhood((-1,1), (-2,2)), CustomNeighborhood((1,2), (2,2))), buf)

    @test neighbors(custom1) isa Base.Generator
    @test collect(neighbors(custom1)) == [0, 1, 1, 0, 0]

    @test sum(custom1) == 2
    @test sum(custom2) == 0
    @test sum(layered) == (1, 2)

    @testset "neighbors works on rule" begin
        rule = Life(;neighborhood=RadialNeighborhood{1}([0 1 1; 0 0 0; 1 1 1]))
        @test sum(neighbors(rule)) == 5
    end
end

struct TestNeighborhoodRule{R,W,N} <: NeighborhoodRule{R,W}
    neighborhood::N
end
DynamicGrids.applyrule(rule::TestNeighborhoodRule, data, state, index, buffer) =
    state

struct TestPartialNeighborhoodRule{R,W,N} <: PartialNeighborhoodRule{R,W}
    neighborhood::N
end
DynamicGrids.applyrule!(rule::TestPartialNeighborhoodRule{R,Tuple{W1,}}, data, state, index
                       ) where {R,W1} =
    data[W1][index...] = state[1]



@testset "neighborhood rules" begin
    ruleA = TestPartialNeighborhoodRule{:a,:a}(RadialNeighborhood{3}())
    ruleB = TestPartialNeighborhoodRule{Tuple{:b},Tuple{:b}}(RadialNeighborhood{2}())
    ruleset = Ruleset(ruleA, ruleB)
    @test neighbors(ruleA) isa Base.Generator
    @test neighborhood(ruleA) == RadialNeighborhood{3}()
    @test neighborhood(ruleB) == RadialNeighborhood{2}()
    @test neighborhoodkey(ruleA) == :a
    @test neighborhoodkey(ruleB) == :b

    ruleA = TestNeighborhoodRule{:a,:a}(RadialNeighborhood{3}())
    ruleB = TestNeighborhoodRule{Tuple{:b},Tuple{:b}}(RadialNeighborhood{2}())
    ruleset = Ruleset(ruleA, ruleB)
    @test neighbors(ruleA) isa Base.Generator
    @test neighborhood(ruleA) == RadialNeighborhood{3}()
    @test neighborhood(ruleB) == RadialNeighborhood{2}()
    @test neighborhoodkey(ruleA) == :a
    @test neighborhoodkey(ruleB) == :b
end

@testset "radius" begin
    init = (a=[1. 2.], b=[10. 11.])
    ruleA = TestNeighborhoodRule{:a,:a}(RadialNeighborhood{3}())
    ruleB = TestPartialNeighborhoodRule{Tuple{:b},Tuple{:b}}(RadialNeighborhood{2}())
    ruleset = Ruleset(ruleA, ruleB)
    @test radius(ruleA) == 3
    @test radius(ruleB) == 2
    @testset "ruleset returns max radii of all rule" begin
        @test radius(ruleset) == (a=3, b=2)
    end
    @test radius(Ruleset()) == NamedTuple()

    output = ArrayOutput(init, 3)
    sim!(output, ruleset; init=init)
    # TODO make sure 2 radii can coexist
end

DynamicGrids.setneighbor!(data, hood, rule::TestPartialNeighborhoodRule,
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

    hood = RadialNeighborhood{1}()
    rule = TestPartialNeighborhoodRule{:a,:a}(hood)
    ruleset = Ruleset(rule)
    simdata = SimData(init, ruleset, 1)
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

    hood = CustomNeighborhood(((-1, -1), (1, 1)))
    rule = TestPartialNeighborhoodRule{:a,:a}(hood)
    ruleset = Ruleset(rule)
    simdata = SimData(init, ruleset, 1)
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


    hood = LayeredCustomNeighborhood(
        (CustomNeighborhood(((-1, -1), (1, 1))), CustomNeighborhood(((-2, -2), (2, 2)))),
        nothing,
    )
    rule = TestPartialNeighborhoodRule{:a,:a}(hood)
    @test radius(rule) === 2
    ruleset = Ruleset(rule)
    simdata = SimData(init, ruleset, 1)
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
    hood = CustomNeighborhood(((-1, -1), (1, 1)))
    @set! hood.coords = ((-5, -5), (5, 5))
    @test hood.coords == ((-5, -5), (5, 5))

    hood = LayeredCustomNeighborhood(
        (CustomNeighborhood(((-1, -1), (1, 1))), CustomNeighborhood(((-2, -2), (2, 2)))),
        nothing,
    )
    @set! hood.layers = (CustomNeighborhood(((-3, -3), (3, 3))),)
    @test hood.layers == (CustomNeighborhood(((-3, -3), (3, 3))),)
end
