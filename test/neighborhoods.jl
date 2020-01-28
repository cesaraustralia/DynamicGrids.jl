using DynamicGrids, Test
import DynamicGrids: sumneighbors, SimData, radius

@testset "sumneighbors" begin
    init = [0 0 0 1 1 1;
            1 0 1 1 0 1;
            0 1 1 1 1 1;
            0 1 0 0 1 0;
            0 0 0 0 1 1;
            0 1 0 1 1 0]

    moore = RadialNeighborhood{1}()
    vonneumann = VonNeumannNeighborhood()
    t = 1

    buf = [0 0 0
           0 1 0
           0 0 0]
    state = buf[2, 2]
    @test sumneighbors(moore, buf, state) == 0
    @test sumneighbors(vonneumann, buf, state) == 0

    buf = [1 1 1
           1 0 1
           1 1 1]
    state = buf[2, 2]
    @test sumneighbors(moore, buf, state) == 8
    @test sumneighbors(vonneumann, buf, state) == 4

    buf = [1 1 1
           0 0 1
           0 0 1]
    state = buf[2, 2]
    @test sumneighbors(moore, buf, state) == 5
    @test sumneighbors(vonneumann, buf, state) == 2


    buf = [0 1 0 0 1
           0 0 1 0 0
           0 0 0 1 1
           0 0 1 0 1
           1 0 1 0 1]
    state = buf[3, 3]
    custom1 = CustomNeighborhood(((-1,-1), (2,-2), (2,2), (-1,2), (0,0)))
    custom2 = CustomNeighborhood(((-1,-1), (0,-1), (1,-1), (2,-1), (0,0)))
    layered = LayeredCustomNeighborhood((CustomNeighborhood((-1,1), (-2,2)), CustomNeighborhood((1,2), (2,2))))

    @test sumneighbors(custom1, buf, state) == 2
    @test sumneighbors(custom2, buf, state) == 0
    @test sumneighbors(layered, buf, state) == (1, 2)
end

struct TestNeighborhoodRule{N} <: NeighborhoodRule
    neighborhood::N
end

struct TestPartialNeighborhoodRule{N} <: PartialNeighborhoodRule
    neighborhood::N
end

struct TestNeighborhoodInteraction{Keys,N} <: NeighborhoodInteraction{Keys}
    neighborhood::N
end

struct TestPartialNeighborhoodInteraction{Keys,N} <: PartialNeighborhoodInteraction{Keys}
    neighborhood::N
end

@testset "radius" begin
    rulesetA = Ruleset(TestNeighborhoodRule(RadialNeighborhood{1}()))
    rulesetB = Ruleset(TestPartialNeighborhoodRule(RadialNeighborhood{5}()))
    interactionA = TestPartialNeighborhoodInteraction{(:a,),RadialNeighborhood{3}}(RadialNeighborhood{3}())
    interactionB = TestPartialNeighborhoodInteraction{(:b,),RadialNeighborhood{2}}(RadialNeighborhood{2}())
    multiruleset = MultiRuleset(
        rulesets = (a = rulesetA, b=rulesetB),
        interactions = (interactionA, interactionB)
    )
    @test DynamicGrids.radius(rulesetA) == 1
    @test DynamicGrids.radius(rulesetB) == 5
    @test DynamicGrids.radius(interactionA) == 3
    @test DynamicGrids.radius(interactionB) == 2
    @testset "multiruleset returns max radii of grid rules and all interactions" begin
        @test DynamicGrids.radius(multiruleset) == (a=3, b=5)
    end
end
