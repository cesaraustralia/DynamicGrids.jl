using DynamicGrids, Test
import DynamicGrids: neighbors, sumneighbors, SimData, radius

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
