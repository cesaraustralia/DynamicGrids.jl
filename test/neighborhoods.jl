using DynamicGrids, Setfield, Test, LinearAlgebra, StaticArrays

using DynamicGrids.Neighborhoods

import DynamicGrids.Neighborhoods: _window, hoodsize, radius

init = [0 0 0 1 1 1
        1 0 1 1 0 1
        0 1 1 1 1 1
        0 1 0 0 1 0
        0 0 0 0 1 1
        0 1 0 1 1 0]

win1 = [0 0 0
        0 1 0
        0 0 0]
win2 = [1 1 1
        1 0 1
        1 1 1]
win3 = [1 1 1
        0 0 1
        0 0 1]

@testset "Moore" begin
    moore = Moore{1}(init[1:3, 1:3])
    @test _window(moore) == init[1:3, 1:3]
    @test hoodsize(moore) == 3
    @test moore[1] == 0
    @test length(moore) == 8
    @test eltype(moore) == Int
    @test neighbors(moore) isa Tuple
    @test collect(neighbors(moore)) == [0, 1, 0, 0, 1, 0, 1, 1]
    @test sum(moore) == sum(neighbors(moore)) == 4
    @test offsets(moore) == 
        ((-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1))

    moore1 = @set moore._window = win1
    @test moore1._window == win1
    moore2 = DynamicGrids.setwindow(moore, win2)
    @test moore2._window == win2

    @test sum(Moore{1}(win1)) == 0
    @test sum(Moore{1}(win2)) == 8
    @test sum(Moore{1}(win3)) == 5
end

@testset "Window" begin
    @test Window{1}() == Window(1) == Window(zeros(3, 3))
    window = Window{1}(init[1:3, 1:3])
    @test _window(window) == init[1:3, 1:3]
    @test hoodsize(window) == 3
    @test window[1] == 0
    @test window[2] == 1
    @test length(window) == 9
    @test eltype(window) == Int
    @test neighbors(window) isa Array 
    @test neighbors(window) == _window(window)
    @test sum(window) == sum(neighbors(window)) == 4
    @test offsets(window) == ((-1, -1), (0, -1), (1, -1), (-1, 0), (0, 0), 
                              (1, 0), (-1, 1), (0, 1), (1, 1))

    window1 = @set window._window = win1
    @test window1._window == win1
    window2 = DynamicGrids.setwindow(window, win2)
    @test window2._window == win2

    @test sum(Window{1}(win1)) == 1
    @test sum(Window{1}(win2)) == 8
    @test sum(Window{1}(win3)) == 5
end

@testset "VonNeumann" begin
    vonneumann = VonNeumann(1, init[1:3, 1:3])
    @test offsets(vonneumann) == ((0, -1), (-1, 0), (1, 0), (0, 1))
    @test _window(vonneumann) == init[1:3, 1:3]
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

    vonneumann1 = @set vonneumann._window = win2
    @test vonneumann1._window == win2
    vonneumann2 = DynamicGrids.setwindow(vonneumann, win3)
    @test vonneumann2._window == win3

    @test sum(VonNeumann(1, win1)) == 0
    @test sum(VonNeumann(1, win2)) == 4
    @test sum(VonNeumann(1, win3)) == 2
end

@testset "Positional" begin
    win = [0 1 0 0 1
           0 0 1 0 0
           0 0 0 1 1
           0 0 1 0 1
           1 0 1 0 1]
    custom1 = Positional(((-1,-1), (2,-2), (2,2), (-1,2), (0,0)), win)
    custom2 = Positional{((-1,-1), (0,-1), (1,-1), (2,-1), (0,0))}(win)
    layered = LayeredPositional(
        (Positional((-1,1), (-2,2)), Positional((1,2), (2,2))), win)

    @test neighbors(custom1) isa Tuple
    @test collect(neighbors(custom1)) == [0, 1, 1, 0, 0]

    @test sum(custom1) == 2
    @test sum(custom2) == 0
    @test sum(layered) == (1, 2)
    @test offsets(layered) == (((-1, 1), (-2, 2)), ((1, 2), (2, 2)))

    layered1 = @set layered._window = 2win
    @test layered1._window == 2win
    layered2 = DynamicGrids.setwindow(layered, 3win)
    @test layered2._window == 3win

    win = reshape(2:10, 3, 3)
    hood = Positional(((-1, -1), (1, 1)), win)
    @test neighbors(hood) == (2, 10)
    @test offsets(hood) == ((-1, -1), (1, 1))
    @test positions(hood, (2, 2)) == ((1, 1), (3, 3))
end

@testset "LayeredPositional" begin
    lhood = LayeredPositional(
        Positional(((-1, -1), (1, 1)), ), Positional(((-2, -2), (2, 2)), )
    )
    @test offsets(lhood) == (((-1, -1), (1, 1)), ((-2, -2), (2, 2)))
    @test collect.(collect(positions(lhood, (1, 1)))) == 
        [[(0, 0), (2, 2)],
         [(-1, -1), (3, 3)]]

    win = reshape(1:25, 5, 5)
    lhood_win = DynamicGrids.setwindow(lhood, win)
    @test lhood_win._window == lhood_win.layers[1]._window === 
          lhood_win.layers[2]._window === win
      lhood_win.layers[2]._window
    @test map(radius, lhood_win.layers) == (2, 2)
    @test neighbors(lhood_win) == ((7, 19), (1, 25))
end

@testset "Kernel" begin
    win = reshape(1:9, 3, 3)
    @testset "Window" begin
        mat = zeros(3, 3)
        @test Kernel(mat) == Kernel(Window(1), mat)
        @test_throws ArgumentError Kernel(Window(2), mat)
        k = Kernel(Window{1,2,9,typeof(win)}(win), SMatrix{3,3}(reshape(1:9, 3, 3)))
        @test kernelproduct(k) == sum((1:9).^2)
        @test neighbors(k) == reshape(1:9, 3, 3)
        @test offsets(k) == ((-1, -1), (0, -1), (1, -1), (-1, 0), (0, 0), 
                             (1, 0), (-1, 1), (0, 1), (1, 1))
        @test positions(k, (2, 2)) == ((1, 1), (2, 1), (3, 1), (1, 2), 
                                       (2, 2), (3, 2), (1, 3), (2, 3), (3, 3))
    end
    @testset "Moore" begin
        k = Kernel(Moore{1,2,8,typeof(win)}(win), (1:4..., 6:9...))
        @test kernelproduct(k) == sum((1:4).^2) + sum((6:9).^2)
    end
    @testset "Positional" begin
        off = ((0,-1),(-1,0),(1,0),(0,1))
        hood = Positional{off,1,2,4,typeof(win)}(win)
        k = Kernel(hood, 1:4)
        @test kernelproduct(k) == 1 * 2 + 2 * 4 + 3 * 6 + 4 * 8
    end
end

@testset "neighbors works on rule" begin
    rule = Life(;stencil=Moore{1}([0 1 1; 0 0 0; 1 1 1]))
    @test sum(neighbors(rule)) == 5
end

@testset "readwindow" begin
    grid1 = [0, 1, 2, 3, 4, 0]
    grid2 = [
         0  0  0  0  0  0
         0  1  2  3  4  0
         0  5  6  7  8  0
         0  9 10 11 12  0
         0  0  0  0  0  0
    ]
    @test DynamicGrids.readwindow(Moore{1,1}(), grid1, (2,)) == [0, 1, 2]
    @test_throws DimensionMismatch DynamicGrids.readwindow(Moore{1,1}(), grid2, (2,))
    @test_throws DimensionMismatch DynamicGrids.readwindow(Moore{1,2}(), grid2, (2,))
    @test DynamicGrids.readwindow(Moore{1,2}(), grid2, (2, 2)) == [0 0 0; 0 1 2; 0 5 6]
    @test DynamicGrids.readwindow(Moore{2,2}(), grid2, (3, 3)) == [0 0 0 0 0; 0 1 2 3 4; 0 5 6 7 8; 0 9 10 11 12; 0 0 0 0 0]
end

@testset "pad/unpad axes" begin
    A = zeros(6, 7)
    @test pad_axes(A, 2) == (-1:8, -1:9) 
    @test pad_axes(A, Moore(3)) == (-2:9, -2:10) 
    @test unpad_axes(A, 2) == (3:4, 3:5)
    @test unpad_axes(A, VonNeumann(1)) == (2:5, 2:6)
end
