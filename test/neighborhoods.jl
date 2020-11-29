using DynamicGrids, Setfield, Test
import DynamicGrids: SimData, Extent, WritableGridData, 
       radius, dest, hoodsize, neighborhoodkey, _buffer

@testset "neighbors" begin
    init = [0 0 0 1 1 1
            1 0 1 1 0 1
            0 1 1 1 1 1
            0 1 0 0 1 0
            0 0 0 0 1 1
            0 1 0 1 1 0]

    moore = Moore{1}(init[1:3, 1:3])

    @test _buffer(moore) == init[1:3, 1:3]
    @test hoodsize(moore) == 3
    @test moore[2, 2] == 0
    @test length(moore) == 8
    @test eltype(moore) == Int
    @test neighbors(moore) isa Base.Generator
    @test collect(neighbors(moore)) == [0, 1, 0, 0, 1, 0, 1, 1]
    @test sum(moore) == sum(neighbors(moore)) == 4
    @test Tuple(offsets(moore)) == ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 0), 
                                    (0, 1), (1, -1), (1, 0), (1, 1))
    vonneumann = VonNeumann(1, init[1:3, 1:3])
    @test offsets(vonneumann) == ((0, -1), (-1, 0), (1, 0), (0, 1))
    @test _buffer(vonneumann) == init[1:3, 1:3]
    @test hoodsize(vonneumann) == 3
    @test vonneumann[2, 1] == 1
    @test length(vonneumann) == 4
    @test eltype(vonneumann) == Int
    @test neighbors(vonneumann) isa Base.Generator
    @test collect(neighbors(vonneumann)) == [1, 0, 1, 1]
    @test sum(neighbors(vonneumann)) == 3
    vonneumann2 = VonNeumann(2)
    @test offsets(vonneumann2) == 
       ((0, -2), (-1, -1), (0, -1), (1, -1), 
         (-2 , 0), (-1, 0), (1, 0), (2, 0), 
         (-1, 1), (0, 1), (1, 1), (0, 2))

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
    @test offsets(layered) == (((-1, 1), (-2, 2)), ((1, 2), (2, 2)))
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
function DynamicGrids.applyrule!(
    data, rule::TestManualNeighborhoodRule{R,Tuple{W1,}}, state, index
) where {R,W1} 
    add!(data[W1], state[1], index...)
end


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
    @test Tuple(offsets(ruleB)) === 
        ((-2, -2), (-2, -1), (-2, 0), (-2, 1), (-2, 2), (-1, -2), (-1, -1), (-1, 0), 
         (-1, 1), (-1, 2), (0, -2), (0, -1), (0, 0), (0, 1), (0, 2), (1, -2), (1, -1), 
         (1, 0), (1, 1), (1, 2), (2, -2), (2, -1), (2, 0), (2, 1), (2, 2))
    @test Tuple(positions(ruleB, (10, 10))) == 
        ((8, 8), (8, 9), (8, 10), (8, 11), (8, 12), (9, 8), (9, 9), (9, 10), (9, 11), 
         (9, 12), (10, 8), (10, 9), (10, 10), (10, 11), (10, 12), (11, 8), (11, 9), 
         (11, 10), (11, 11), (11, 12), (12, 8), (12, 9), (12, 10), (12, 11), (12, 12))
end

@testset "radius" begin
    init = (a=[1.0 2.0], b=[10.0 11.0])
    ruleA = TestNeighborhoodRule{:a,:a}(Moore{3}())
    ruleB = TestManualNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}())
    ruleset = Ruleset(ruleA, ruleB)
    @test radius(ruleA) == 3
    @test radius(ruleB) == 2
    @test radius(ruleset) == (a=3, b=2)
    @test radius(Ruleset()) == NamedTuple()

    output = ArrayOutput(init; tspan=1:3)
    sim!(output, ruleset)
    # TODO make sure 2 radii can coexist
end

@testset "Positional" begin
    hood = Positional(((-1, -1), (1, 1)))
    @set! hood.offsets = ((-5, -5), (5, 5))
    @test offsets(hood) == hood.offsets == ((-5, -5), (5, 5))

    hood = LayeredPositional(
        (Positional(((-1, -1), (1, 1))), Positional(((-2, -2), (2, 2)))),
        nothing,
    )
    @set! hood.layers = (Positional(((-3, -3), (3, 3))),)
    @test hood.layers == (Positional(((-3, -3), (3, 3))),)
end
