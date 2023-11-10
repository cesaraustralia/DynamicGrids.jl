using DynamicGrids, Dates, DimensionalData, Setfield, Unitful, Test, DimensionalData
using Unitful: d
using DynamicGrids: SimData, Extent, _calc_auxframe
const DG = DynamicGrids

@testset "Aux" begin
    @testset "aux sequence" begin
        a = cat([0.1 0.2; 0.3 0.4], [1.1 1.2; 1.3 1.4], [2.1 2.2; 2.3 2.4]; dims=3)

        @testset "the correct frame is calculated for aux data" begin
            dimz = X(1:2), Y(1:2), Ti(DimensionalData.Cyclic(1d:5d:14d; order=ForwardOrdered(), cycle=15d, sampling=Intervals(Start())))
            seq = DimArray(a, dimz)
            init = zero(seq[Ti(1)])
            sd = SimData(Extent(init=init, aux=(seq=seq,), tspan=1d:1d:100d), Ruleset())
            @test DynamicGrids.boundscheck_aux(sd, Aux{:seq}()) == true
            tests = (1, 1), (4, 1), (5, 1), (6, 2), (9, 2), (10, 2), (11, 3), (14, 3), (15, 3), 
                    (20, 1), (21, 2), (26, 3), (30, 3), (31, 1), (35, 1), (36, 2)
            for (f, ref_af) in tests
                @set! sd.currentframe = f
                af = _calc_auxframe(sd).seq
                @test af == ref_af 
            end
            # Not Cycled
            dimz = X(1:2), Y(1:2), Ti(1d:5d:14d; order=ForwardOrdered(), cycle=15d, sampling=Intervals(Start()))
            seq = DimArray(a, dimz)
            init = zero(seq[Ti(1)])
            sd = SimData(Extent(init=init, aux=(seq=seq,), tspan=1d:1d:100d), Ruleset())
            @set! sd.currentframe = 20
            @test_throws ArgumentError _calc_auxframe(sd).seq
            # Not Intervals
            dimz = X(1:2), Y(1:2), Ti(DimensionalData.Cyclic(1d:5d:14d; order=ForwardOrdered(), cycle=15d, sampling=Points()))
            seq = DimArray(a, dimz)
            init = zero(seq[Ti(1)])
            sd = SimData(Extent(init=init, aux=(seq=seq,), tspan=1d:1d:100d), Ruleset())
            @set! sd.currentframe = 7
            @test_throws ArgumentError _calc_auxframe(sd).seq
        end

        @testset "boundscheck_aux" begin
            seq1 = zeros(Ti(15d:5d:25d))
            seq3 = zeros((X(1:2), Y(1:2), Ti(15d:5d:25d)))
            auxarray1 = zeros(X(3))
            auxarray2 = zeros(dims(seq3, (X, Y)))
            bigseq = zeros((X(1:5), Y(1:2), Ti(15d:5d:25d)))
            aux1 = (seq=seq1, a1=auxarray1, a2=auxarray2)
            sd1 = SimData(Extent(init=zeros(3), aux=aux1, tspan=1d:1d:100d), Ruleset())
            aux2 = (seq=seq3, bigseq=bigseq, a1=auxarray1, a2=auxarray2)
            sd2 = SimData(Extent(init=zero(seq3[Ti(1)]), aux=aux2, tspan=1d:1d:100d), Ruleset())
            @test DynamicGrids.boundscheck_aux(sd1, Aux{:seq}()) == true
            @test DynamicGrids.boundscheck_aux(sd1, Aux{:a1}()) == true
            @test DynamicGrids.boundscheck_aux(sd2, Aux{:seq}()) == true
            @test DynamicGrids.boundscheck_aux(sd2, Aux{:a2}()) == true
            @test_throws ErrorException DynamicGrids.boundscheck_aux(sd1, Aux{:a2}())
            @test_throws ErrorException DynamicGrids.boundscheck_aux(sd2, Aux{:a1}())
            @test_throws ErrorException DynamicGrids.boundscheck_aux(sd2, Aux{:bigseq}())
            @test_throws ErrorException DynamicGrids.boundscheck_aux(sd2, Aux{:missingseq}())
        end

        @testset "correct values are returned by get" begin
            x, y, ti = X(1:2), Y(1:2), Ti(Date(2001, 1, 15):Day(5):Date(2001, 1, 25))
            @testset "1d" begin
                seq1 = DimArray(a[2, 2, :], ti)
                seq3 = DimArray(a[:, 1, :], (x, ti))
                init = zero(seq3[Ti(1)])
                tspan = Date(2001):Day(1):Date(2001, 3)
                data = SimData(Extent(init=init, aux=(; seq1, seq3), tspan=tspan), Ruleset())
                data1 = DG._updatetime(data, 1)
                @test data1.auxframe == (seq1 = 1, seq3 = 1,)
                # I is ignored for 1d with Ti dim
                @test get(data1, Aux(:seq1), (-10,)) == 0.4
                @test get(data1, Aux(:seq3), (1)) == 0.1
                dims(seq1, Ti) === dims(seq3, Ti)
                data2 = DG._updatetime(data, 5);
                @test data2.auxframe == (seq1 = 2, seq3 = 2,)
                @test get(data2, Aux(:seq1), 11) == 1.4
                @test get(data2, Aux(:seq3), 1) == 1.1
                data3 = DG._updatetime(data, 10)
                @test data3.auxframe == (seq1 = 3, seq3 = 3,)
                @test get(data3, Aux(:seq1), (1,)) == 2.4
                @test get(data3, Aux(:seq3), (1,)) == 2.1
                data4 = DG._updatetime(data, 15)
                @test data4.auxframe == (seq1 = 1, seq3 = 1,)
                @test get(data4, Aux(:seq1), CartesianIndex(1,)) == 0.4
                @test get(data4, Aux(:seq3), CartesianIndex(1,)) == 0.1
            end
            @testset "2d" begin
                seq1 = DimArray(a[2, 2, :], ti)
                seq3 = DimArray(a, (x, y, ti))
                init = zero(seq3[Ti(1)])
                tspan = Date(2001):Day(1):Date(2001, 3)
                data = SimData(Extent(init=init, aux=(; seq1, seq3), tspan=tspan), Ruleset())
                data1 = DG._updatetime(data, 1)
                @test data1.auxframe == (seq1 = 1, seq3 = 1,)
                # I is ignored for 1d with Ti dim
                @test get(data1, Aux(:seq1), (-10, 17)) == 0.4
                @test get(data1, Aux(:seq3), (1, 1)) == 0.1
                dims(seq1, Ti) === dims(seq3, Ti)
                data2 = DG._updatetime(data, 5);
                @test data2.auxframe == (seq1 = 2, seq3 = 2,)
                @test get(data2, Aux(:seq1), 11, 1) == 1.4
                @test get(data2, Aux(:seq3), 1, 1) == 1.1
                data3 = DG._updatetime(data, 10)
                @test data3.auxframe == (seq1 = 3, seq3 = 3,)
                @test get(data3, Aux(:seq1), (1, 10)) == 2.4
                @test get(data3, Aux(:seq3), (1, 1)) == 2.1
                data4 = DG._updatetime(data, 15)
                @test data4.auxframe == (seq1 = 1, seq3 = 1,)
                @test get(data4, Aux(:seq1), CartesianIndex(1, 1)) == 0.4
                @test get(data4, Aux(:seq3), CartesianIndex(1, 1)) == 0.1
            end
        end

        @testset "errors" begin
            output = ArrayOutput(zeros(3, 3); tspan=1:3)
            @test_throws ArgumentError  DynamicGrids.aux(output, Aux{:somekey}())
        end

    end
end

# Use copyto to test all parametersources, as well as testing CopyTo itself
@testset "CopyTo" begin
    init = [0 0]

    @testset "Copy construction" begin
        rule = CopyTo(7)
        rule2 = @set rule.from = Aux{:a}()
        @test rule2.from == Aux{:a}()
    end

    @testset "CopyTo from value" begin
        ruleset = Ruleset(CopyTo(7))
        output = ArrayOutput(init; tspan=1d:1d:3d)
        sim!(output, ruleset)
        @test output == [[0 0], [7 7], [7 7]]
    end

    @testset "CopyTo from Grid" begin
        @test CopyTo(Aux(:l)) === CopyTo(; from=Aux(:l))
        @test CopyTo{:a}(; from=Aux(:l)) === CopyTo{:a}(Aux(:l))
        ruleset = Ruleset(CopyTo(Aux(:l)))
        output = ArrayOutput(init; tspan=1:3, aux=(l=[3 4],))
        sim!(output, ruleset)
        @test output == [[0 0], [3 4], [3 4]]

        da = DimArray(cat([1 2], [3 4]; dims=3) , (X(), Y(), Ti(4d:1d:5d)))
        output = ArrayOutput(init; tspan=1d:1d:3d, aux=(l=da,))
        sim!(output, ruleset)
        @test output == [[0 0], [1 2], [3 4]]
    end

    @testset "CopyTo from Grid" begin
        ruleset = Ruleset(Cell{:s,:s}((d, x, I) -> x + 1), CopyTo{:d}(from=Grid(:s)))
        output = ArrayOutput((s=[1 3], d=[0 0],); tspan=1d:1d:3d)
        sim!(output, ruleset)
        @test output == [(s=[1 3], d=[0 0]), (s=[2 4], d=[2 4]), (s=[3 5], d=[3 5])]

        ruleset = Ruleset(Cell{:s,:s}((d, x, I) -> x + 1), CopyTo{Tuple{:d1,:d2}}(from=Grid{:s}()))
        output = ArrayOutput((s=[1 3], d1=[0 0], d2=[-1 -1],); tspan=1d:1d:3d)
        sim!(output, ruleset)
        @test output == [(s=[1 3], d1=[0 0], d2=[-1 -1]), 
                         (s=[2 4], d1=[2 4], d2=[2 4]), 
                         (s=[3 5], d1=[3 5], d2=[3 5])]
    end

    @testset "CopyTo from Delay" begin
        ruleset = Ruleset(Cell{:s,:s}((d, x, I) -> x + 1), CopyTo{:d}(from=Delay{:s}(1d)))
        @test DynamicGrids.hasdelay(rules(ruleset)) == true
        output = ArrayOutput((s=[1 3], d=[0 0],); tspan=1d:1d:4d)
        sim!(output, ruleset)
        @test output == [
            (s=[1 3], d=[0 0]), 
            (s=[2 4], d=[1 3]), 
            (s=[3 5], d=[2 4]), 
            (s=[4 6], d=[3 5])
        ]

        ruleset = Ruleset(Cell{:s,:s}((d, x, I) -> x + 1), CopyTo{:d}(from=Delay{:s}(Month(2))))
        @test DynamicGrids.hasdelay(rules(ruleset)) == true
        output = ArrayOutput((s=[1 3], d=[0 0]); tspan=Date(2001):Month(1):Date(2001, 6))
        sim!(output, ruleset)
        @test output == [
            (s=[1 3],   d=[0 0]), 
            (s=[2 4],   d=[1 3]), 
            (s=[3 5],   d=[1 3]),
            (s=[4 6],   d=[2 4]),
            (s=[5 7],   d=[3 5]),
            (s=[6 8],   d=[4 6]),
        ]                   

    end

    @testset "CopyTo from Lag" begin
        ruleset = Ruleset(Cell{:s,:s}((d, x, I) -> x + 1), CopyTo{:d}(from=Lag{:s}(1)))
        @test DynamicGrids.hasdelay(rules(ruleset)) == true
        output = ArrayOutput((s=[1 3], d=[0 0],); tspan=1d:1d:4d)
        sim!(output, ruleset)
        @test output == [
            (s=[1 3], d=[0 0]), 
            (s=[2 4], d=[1 3]), 
            (s=[3 5], d=[2 4]), 
            (s=[4 6], d=[3 5])
        ]

    end
end
