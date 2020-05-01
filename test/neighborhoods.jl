using DynamicGrids, Test
import DynamicGrids: neighbors, sumneighbors, SimData, radius, neighbors,
       mapsetneighbor!, neighborhood, WritableGridData, dest, hoodsize, neighborhoodkey


@testset "neighbors" begin
    init = [0 0 0 1 1 1;
            1 0 1 1 0 1;
            0 1 1 1 1 1;
            0 1 0 0 1 0;
            0 0 0 0 1 1;
            0 1 0 1 1 0]

    moore = RadialNeighborhood{1}()
    buf = init[1:3, 1:3]

    @test hoodsize(moore) == 3 
    @test neighbors(moore, buf) isa Base.Generator
    @test collect(neighbors(moore, buf)) == [0, 1, 0, 0, 1, 0, 1, 1]
    @test sum(neighbors(moore, buf)) == 4

    vonneumann = VonNeumannNeighborhood()
    @test hoodsize(vonneumann) == 3 
    t = 1

    buf = [0 0 0
           0 1 0
           0 0 0]
    state = buf[2, 2]
    @test sumneighbors(moore, buf, state) == sum(neighbors(moore, buf)) == 0
    @test sumneighbors(vonneumann, buf, state) == 0

    buf = [1 1 1
           1 0 1
           1 1 1]
    state = buf[2, 2]
    collect(neighbors(moore, buf))
    @test sumneighbors(moore, buf, state) == sum(neighbors(moore, buf)) == 8
    @test sumneighbors(vonneumann, buf, state) == 4

    buf = [1 1 1
           0 0 1
           0 0 1]
    state = buf[2, 2]
    @test sumneighbors(moore, buf, state) == sum(neighbors(moore, buf)) == 5
    @test sumneighbors(vonneumann, buf, state) == 2


    buf = [0 1 0 0 1
           0 0 1 0 0
           0 0 0 1 1
           0 0 1 0 1
           1 0 1 0 1]
    state = buf[3, 3]
    custom1 = CustomNeighborhood(((-1,-1), (2,-2), (2,2), (-1,2), (0,0)))
    custom2 = CustomNeighborhood(((-1,-1), (0,-1), (1,-1), (2,-1), (0,0)))
    layered = LayeredCustomNeighborhood((CustomNeighborhood((-1,1), (-2,2)), 
                                         CustomNeighborhood((1,2), (2,2))))

    @test neighbors(custom1, buf) isa Base.Generator
    @test collect(neighbors(custom1, buf)) == [0, 1, 1, 0, 0]

    @test sumneighbors(custom1, buf, state) == sum(neighbors(custom1, buf)) == 2
    @test sumneighbors(custom2, buf, state) == sum(neighbors(custom2, buf)) == 0
    @test sumneighbors(layered, buf, state) == sum.(neighbors(layered, buf)) == (1, 2)
end

struct TestNeighborhoodRule{R,W,N} <: NeighborhoodRule{R,W}
    neighborhood::N
end

struct TestPartialNeighborhoodRule{R,W,N} <: PartialNeighborhoodRule{R,W}
    neighborhood::N
end

@testset "neighborhood" begin
    ruleA = TestPartialNeighborhoodRule{:a,:a}(RadialNeighborhood{3}())
    ruleB = TestPartialNeighborhoodRule{Tuple{:b},Tuple{:b}}(RadialNeighborhood{2}())
    ruleset = Ruleset(ruleA, ruleB)
    @test neighborhood(ruleA) == RadialNeighborhood{3}()
    @test neighborhood(ruleB) == RadialNeighborhood{2}()
    @test neighborhoodkey(ruleA) == :a
    @test neighborhoodkey(ruleB) == :b

    ruleA = TestNeighborhoodRule{:a,:a}(RadialNeighborhood{3}())
    ruleB = TestNeighborhoodRule{Tuple{:b},Tuple{:b}}(RadialNeighborhood{2}())
    ruleset = Ruleset(ruleA, ruleB)
    @test neighborhood(ruleA) == RadialNeighborhood{3}()
    @test neighborhood(ruleB) == RadialNeighborhood{2}()
    @test neighborhoodkey(ruleA) == :a
    @test neighborhoodkey(ruleB) == :b
end

@testset "radius" begin
    ruleA = TestNeighborhoodRule{:a,:a}(RadialNeighborhood{3}())
    ruleB = TestPartialNeighborhoodRule{Tuple{:b},Tuple{:b}}(RadialNeighborhood{2}())
    ruleset = Ruleset(ruleA, ruleB)
    @test DynamicGrids.radius(ruleA) == 3
    @test DynamicGrids.radius(ruleB) == 2
    @testset "ruleset returns max radii of all rule" begin
        @test DynamicGrids.radius(ruleset) == (a=3, b=2)
    end
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

end
