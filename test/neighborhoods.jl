using DynamicGrids, Setfield, Test, LinearAlgebra, StaticArrays
import DynamicGrids: SimData, Extent, WritableGridData, 
       radius, dest, hoodsize, neighborhoodkey, _buffer

@testset "neighbors" begin
    init = [0 0 0 1 1 1
            1 0 1 1 0 1
            0 1 1 1 1 1
            0 1 0 0 1 0
            0 0 0 0 1 1
            0 1 0 1 1 0]

    buf1 = [0 0 0
            0 1 0
            0 0 0]
    buf2 = [1 1 1
            1 0 1
            1 1 1]
    buf3 = [1 1 1
            0 0 1
            0 0 1]

    @testset "Moore" begin
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

        moore1 = @set moore._buffer = buf1
        @test moore1._buffer == buf1
        moore2 = DynamicGrids._setbuffer(moore, buf2)
        @test moore2._buffer == buf2

        @test sum(Moore{1}(buf1)) == 0
        @test sum(Moore{1}(buf2)) == 8
        @test sum(Moore{1}(buf3)) == 5
    end
    @testset "Window" begin
        window = Window{1}(init[1:3, 1:3])
        @test _buffer(window) == init[1:3, 1:3]
        @test hoodsize(window) == 3
        @test window[2, 2] == 0
        @test length(window) == 9
        @test eltype(window) == Int
        @test neighbors(window) isa Array 
        @test neighbors(window) == _buffer(window)
        @test sum(window) == sum(neighbors(window)) == 4
        @test Tuple(offsets(window)) == ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 0), 
                                        (0, 1), (1, -1), (1, 0), (1, 1))

        window1 = @set window._buffer = buf1
        @test window1._buffer == buf1
        window2 = DynamicGrids._setbuffer(window, buf2)
        @test window2._buffer == buf2

        @test sum(Window{1}(buf1)) == 1
        @test sum(Window{1}(buf2)) == 8
        @test sum(Window{1}(buf3)) == 5
    end
    @testset "VonNeumann/Positional" begin
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

        vonneumann1 = @set vonneumann._buffer = buf2
        @test vonneumann1._buffer == buf2
        vonneumann2 = DynamicGrids._setbuffer(vonneumann, buf3)
        @test vonneumann2._buffer == buf3

        @test sum(VonNeumann(1, buf1)) == 0
        @test sum(VonNeumann(1, buf2)) == 4
        @test sum(VonNeumann(1, buf3)) == 2
    end
    @testset "Layered/Positional" begin
        buf = [0 1 0 0 1
               0 0 1 0 0
               0 0 0 1 1
               0 0 1 0 1
               1 0 1 0 1]
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

        layered1 = @set layered._buffer = 2buf
        @test layered1._buffer == 2buf
        layered2 = DynamicGrids._setbuffer(layered, 3buf)
        @test layered2._buffer == 3buf
    end
    @testset "neighbors works on rule" begin
        rule = Life(;neighborhood=Moore{1}([0 1 1; 0 0 0; 1 1 1]))
        @test sum(neighbors(rule)) == 5
    end

end

@testset "Kernel" begin
    buf = reshape(1:9, 3, 3)
    @testset "Window" begin
        k = Kernel(Window{1,9,typeof(buf)}(buf), SMatrix{3,3}(reshape(1:9, 3, 3)))
        @test dot(k) == sum((1:9).^2)
    end
    @testset "Moore" begin
        k = Kernel(Moore{1,8,typeof(buf)}(buf), (1:4..., 6:9...))
        @test dot(k) == sum((1:4).^2) + sum((6:9).^2)
    end
    @testset "Positional" begin
        off = ((0,-1),(-1,0),(1,0),(0,1))
        hood = Positional{1,4,typeof(off),typeof(buf)}(off, buf)
        k = Kernel(hood, 1:4)
        @test dot(k) == 1 * 2 + 2 * 4 + 3 * 6 + 4 * 8
    end
end

struct TestNeighborhoodRule{R,W,N} <: NeighborhoodRule{R,W}
    neighborhood::N
end
DynamicGrids.applyrule(data, rule::TestNeighborhoodRule, state, index) = state

struct TestSetNeighborhoodRule{R,W,N} <: SetNeighborhoodRule{R,W}
    neighborhood::N
end
function DynamicGrids.applyrule!(
    data, rule::TestSetNeighborhoodRule{R,Tuple{W1,}}, state, index
) where {R,W1} 
    add!(data[W1], state[1], index...)
end


@testset "neighborhood rules" begin
    ruleA = TestSetNeighborhoodRule{:a,:a}(Moore{3}())
    ruleB = TestSetNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}())
    @test offsets(ruleA) isa Base.Generator
    @test positions(ruleA, (1, 1)) isa Base.Generator
    @test neighborhood(ruleA) == Moore{3}()
    @test neighborhood(ruleB) == Moore{2}()
    @test neighborhoodkey(ruleA) == :a
    @test neighborhoodkey(ruleB) == :b
    ruleA = TestNeighborhoodRule{:a,:a}(Moore{3}())
    ruleB = TestNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}())
    @test neighbors(ruleA) isa Base.Generator
    @test offsets(ruleA) isa Base.Generator
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
    ruleB = TestSetNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}())
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
