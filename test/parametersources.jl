using DynamicGrids, Dates, DimensionalData, Setfield, Unitful, Test
using Unitful: d
using DynamicGrids: SimData, Extent, _calc_auxframe, _cyclic_index
const DG = DynamicGrids

@testset "Aux" begin
    @testset "sequence cycling" begin
        @test _cyclic_index(-4, 2) == 2
        @test _cyclic_index(-3, 2) == 1
        @test _cyclic_index(-2, 2) == 2
        @test _cyclic_index(-1, 2) == 1
        @test _cyclic_index(0, 2) == 2
        @test _cyclic_index(1, 2) == 1
        @test _cyclic_index(2, 2) == 2
        @test _cyclic_index(3, 2) == 1
        @test _cyclic_index(4, 2) == 2
        @test _cyclic_index(20, 10) == 10
        @test _cyclic_index(21, 10) == 1
        @test _cyclic_index(27, 10) == 7
    end

    @testset "aux sequence" begin
        a = cat([0.1 0.2; 0.3 0.4], [1.1 1.2; 1.3 1.4], [2.1 2.2; 2.3 2.4]; dims=3)

        @testset "the correct frame is calculated for aux data" begin
            dimz = X(1:2), Y(1:2), Ti(15d:5d:25d)
            seq = DimensionalArray(a, dimz)
            init = zero(seq[Ti(1)])
            sd = SimData(Extent(init=init, aux=(seq=seq,), tspan=1d:1d:100d), Ruleset())
            @test DynamicGrids.boundscheck_aux(sd, Aux{:seq}()) == true
            tests = (1, 1), (4, 1), (5, 2), (6, 2), (9, 2), (10, 3), (11, 3), (14, 3), (15, 1), 
                    (19, 1), (20, 2), (25, 3), (29, 3), (30, 1), (34, 1), (35, 2)
            for (f, ref_af) in tests
                @set! sd.currentframe = f
                af = _calc_auxframe(sd).seq
                @test af == ref_af 
            end
        end

        @testset "boundscheck_aux" begin
            seq = DimensionalArray(a, (X(1:2), Y(1:2), Ti(15d:5d:25d)))
            bigseq = DimensionalArray(zeros(5, 2, 3), (X(1:5), Y(1:2), Ti(15d:5d:25d)))
            init = zero(seq[Ti(1)])
            sd = SimData(Extent(init=init, aux=(seq=seq, bigseq=bigseq), tspan=1d:1d:100d), Ruleset())
            @test DynamicGrids.boundscheck_aux(sd, Aux{:seq}()) == true
            @test_throws ErrorException DynamicGrids.boundscheck_aux(sd, Aux{:bigseq}())
            @test_throws ErrorException DynamicGrids.boundscheck_aux(sd, Aux{:missingseq}())
        end

        @testset "correct values are returned by get" begin
            dimz = X(1:2), Y(1:2), Ti(Date(2001, 1, 15):Day(5):Date(2001, 1, 25))
            seq = DimensionalArray(a, dimz)
            init = zero(seq[Ti(1)])
            data = SimData(Extent(init=init, aux=(seq=seq,), tspan=Date(2001):Day(1):Date(2001, 3)), Ruleset())
            data1 = DG._updatetime(data, 1)
            @test data1.auxframe == (seq = 1,)
            @test get(data1, Aux(:seq), 1, 1) == 0.1
            data2 = DG._updatetime(data, 5)
            @test data2.auxframe == (seq = 2,)
            @test get(data2, Aux(:seq), 1, 1) == 1.1
            data3 = DG._updatetime(data, 10)
            @test data3.auxframe == (seq = 3,)
            @test get(data3, Aux(:seq), 1, 1) == 2.1
            data4 = DG._updatetime(data, 15)
            @test data4.auxframe == (seq = 1,)
            @test get(data4, Aux(:seq), 1, 1) == 0.1
        end

        @testset "errors" begin
            output = ArrayOutput(zeros(3, 3); tspan=1:3)
            @test_throws ArgumentError  DynamicGrids.aux(output, Aux{:somekey}())
        end
    end
end

# Use copyto to test all parametersources, as well as testing CopyTo itself
@testset "CopyTo" begin
    @testset "Copy construction" begin
        rule = CopyTo(7)
        rule2 = @set rule.from = Aux{:a}()
        @test rule2.from == Aux{:a}()
    end

    init = [0 0]

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
