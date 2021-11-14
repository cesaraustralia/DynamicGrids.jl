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
        @test moore[1] == 0
        @test length(moore) == 8
        @test eltype(moore) == Int
        @test neighbors(moore) isa Tuple
        @test collect(neighbors(moore)) == [0, 1, 0, 0, 1, 0, 1, 1]
        @test sum(moore) == sum(neighbors(moore)) == 4
        @test offsets(moore) == 
            ((-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1))

        moore1 = @set moore._buffer = buf1
        @test moore1._buffer == buf1
        moore2 = DynamicGrids._setbuffer(moore, buf2)
        @test moore2._buffer == buf2

        @test sum(Moore{1}(buf1)) == 0
        @test sum(Moore{1}(buf2)) == 8
        @test sum(Moore{1}(buf3)) == 5
    end
    @testset "Window" begin
        @test Window{1}() == Window(1) == Window(zeros(3, 3))
        window = Window{1}(init[1:3, 1:3])
        @test _buffer(window) == init[1:3, 1:3]
        @test hoodsize(window) == 3
        @test window[1] == 0
        @test window[2] == 1
        @test length(window) == 9
        @test eltype(window) == Int
        @test neighbors(window) isa Array 
        @test neighbors(window) == _buffer(window)
        @test sum(window) == sum(neighbors(window)) == 4
        @test offsets(window) == ((-1, -1), (0, -1), (1, -1), (-1, 0), (0, 0), 
                                  (1, 0), (-1, 1), (0, 1), (1, 1))

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
        @test vonneumann[1] == 1
        @test vonneumann[2] == 0
        @test length(vonneumann) == 4
        @test eltype(vonneumann) == Int
        @test neighbors(vonneumann) isa Tuple
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

        @test neighbors(custom1) isa Tuple
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
        mat = zeros(3, 3)
        @test Kernel(mat) == Kernel(Window(1), mat)
        @test_throws ArgumentError Kernel(Window(2), mat)
        k = Kernel(Window{1,9,typeof(buf)}(buf), SMatrix{3,3}(reshape(1:9, 3, 3)))
        @test kernelproduct(k) == sum((1:9).^2)
        @test neighbors(k) == reshape(1:9, 3, 3)
        @test offsets(k) == ((-1, -1), (0, -1), (1, -1), (-1, 0), (0, 0), 
                             (1, 0), (-1, 1), (0, 1), (1, 1))
        @test positions(k, (2, 2)) == ((1, 1), (2, 1), (3, 1), (1, 2), 
                                       (2, 2), (3, 2), (1, 3), (2, 3), (3, 3))
    end
    @testset "Moore" begin
        k = Kernel(Moore{1,8,typeof(buf)}(buf), (1:4..., 6:9...))
        @test kernelproduct(k) == sum((1:4).^2) + sum((6:9).^2)
    end
    @testset "Positional" begin
        off = ((0,-1),(-1,0),(1,0),(0,1))
        hood = Positional{1,4,typeof(off),typeof(buf)}(off, buf)
        k = Kernel(hood, 1:4)
        @test kernelproduct(k) == 1 * 2 + 2 * 4 + 3 * 6 + 4 * 8
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

buf5x5 = zeros(5, 5)
buf7x7 = zeros(7, 7)


@testset "neighborhood rules" begin
    ruleA = TestSetNeighborhoodRule{:a,:a}(Moore{3}(buf7x7))
    ruleB = TestSetNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}(buf5x5))
    @test offsets(ruleA) isa Tuple
    @test positions(ruleA, (1, 1)) isa Tuple
    @test neighborhood(ruleA) == Moore{3}(buf7x7)
    @test neighborhood(ruleB) == Moore{2}(buf5x5)
    @test neighborhoodkey(ruleA) == :a
    @test neighborhoodkey(ruleB) == :b
    ruleA = TestNeighborhoodRule{:a,:a}(Moore{3}(buf7x7))
    ruleB = TestNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}(buf5x5))
    @test offsets(ruleA) isa Tuple
    @test neighborhood(ruleA) == Moore{3}(buf7x7)
    @test neighborhood(ruleB) == Moore{2}(buf5x5)
    @test neighborhoodkey(ruleA) == :a
    @test neighborhoodkey(ruleB) == :b
    @test offsets(ruleB) === 
        ((-2,-2), (-1,-2), (0,-2), (1,-2), (2,-2),
         (-2,-1), (-1,-1), (0,-1), (1,-1), (2,-1),
         (-2,0), (-1,0), (1,0), (2,0),
         (-2,1), (-1,1), (0,1), (1,1), (2,1),
         (-2,2), (-1,2), (0,2), (1,2), (2,2))
    @test positions(ruleB, (10, 10)) == 
        ((8, 8), (9, 8), (10, 8), (11, 8), (12, 8), 
         (8, 9), (9, 9), (10, 9), (11, 9), (12, 9), 
         (8, 10), (9, 10), (11, 10), (12, 10), 
         (8, 11), (9, 11), (10, 11), (11, 11), (12, 11), 
         (8, 12), (9, 12), (10, 12), (11, 12), (12, 12))
end

@testset "radius" begin
    init = (a=[1.0 2.0], b=[10.0 11.0])
    ruleA = TestNeighborhoodRule{:a,:a}(Moore{3}(buf7x7))
    ruleB = TestSetNeighborhoodRule{Tuple{:b},Tuple{:b}}(Moore{2}(buf5x5))
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
    buf = reshape(2:10, 3, 3)
    hood = Positional(((-1, -1), (1, 1)), buf)
    @test Tuple(neighbors(hood)) == (2, 10)
    @test offsets(hood) == ((-1, -1), (1, 1))
    @test Tuple(positions(hood, (2, 2))) == ((1, 1), (3, 3))
    @set! hood.offsets = ((-5, -5), (5, 5))
    @test offsets(hood) == hood.offsets == ((-5, -5), (5, 5))
end

@testset "LayeredPositional" begin
    lhood = LayeredPositional(
        Positional(((-1, -1), (1, 1)), ), Positional(((-2, -2), (2, 2)), )
    )
    @test offsets(lhood) == (((-1, -1), (1, 1)), ((-2, -2), (2, 2)))
    @test collect.(collect(positions(lhood, (1, 1)))) == 
        [[(0, 0), (2, 2)],
         [(-1, -1), (3, 3)]]

    buf = reshape(1:25, 5, 5)
    lhood_buf = DynamicGrids._setbuffer(lhood, buf)
    @test lhood_buf._buffer == lhood_buf.layers[1]._buffer === 
          lhood_buf.layers[2]._buffer === buf
    @test map(radius, lhood_buf.layers) == (2, 2)
    @test map(Tuple, neighbors(lhood_buf)) == ((7, 19), (1, 25))
end
