using DynamicGrids, StaticArrays, Test

@testset "CellRule that multiples a StaticArray" begin
    rule = Cell{:grid1,:grid1}() do state
         2state
    end
    init = (grid1 = fill(SA[1.0, 2.0], 5, 5),)
    output = ArrayOutput(init; tspan=1:3)
    sim!(output, rule)
    @test output[2][:grid1] == reshape([ # Have to use reshape to construct this
        SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0],
        SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0],
        SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], 
        SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], 
        SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0], SA[2.0, 4.0]
    ], (5, 5))
    @test output[3][:grid1] == reshape([ # Have to use reshape to construct this
        SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0],
        SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0],
        SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], 
        SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], 
        SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0], SA[4.0, 8.0]
    ], (5, 5))
end

@testset "Neighborhood Rule that sums a Neighborhood of StaticArrays" begin
    rule = Neighbors{Tuple{:grid1,:grid2}, :grid1}(Moore(1)) do neighborhood, state1, state2
        sum(neighborhood) .+ state2
    end
    init = (
        grid1 = fill(SA[1.0, 2.0], 5, 5),
        grid2 = fill(0.5, 5, 5),
    )
    output = ArrayOutput(init; tspan=1:2)
    sim!(output, rule)
    @test output[2][:grid1] == reshape([ # Have to use reshape to construct this
        SA[3.5, 6.5],  SA[5.5, 10.5], SA[5.5, 10.5], SA[5.5, 10.5], SA[3.5, 6.5],
        SA[5.5, 10.5], SA[8.5, 16.5], SA[8.5, 16.5], SA[8.5, 16.5], SA[5.5, 10.5],
        SA[5.5, 10.5], SA[8.5, 16.5], SA[8.5, 16.5], SA[8.5, 16.5], SA[5.5, 10.5], 
        SA[5.5, 10.5], SA[8.5, 16.5], SA[8.5, 16.5], SA[8.5, 16.5], SA[5.5, 10.5], 
        SA[3.5, 6.5],  SA[5.5, 10.5], SA[5.5, 10.5], SA[5.5, 10.5], SA[3.5, 6.5]
    ], (5, 5))
end

@testset "ManualRule randomly updates a StaticArray" begin
    rule = Manual{:grid1,:grid1}() do data, I, state
        if I == (2, 2) || I == (1, 3)
            data[:grid1][I...] = SA[99.0, 100.0]
        end
    end
    init = (grid1 = fill(SA[0.0, 0.0], 3, 3),)
    output = ArrayOutput(init; tspan=1:2)
    sim!(output, rule)
    @test output[2][:grid1] == reshape([ # Have to use reshape to construct this
        SA[0.0, 0.0], SA[0.0, 0.0], SA[0.0, 0.0], 
        SA[0.0, 0.0], SA[99.0, 100.0], SA[0.0, 0.0], 
        SA[99.0, 100.0], SA[0.0, 0.0], SA[0.0, 0.0]
    ], (3, 3))
end


struct TestStruct{A,B}
    a::A
    b::B
end
const TS = TestStruct

Base.:*(ts::TestStruct, x::Number) = TestStruct(x * ts.a, x * ts.b) 
Base.:*(x::Number, ts::TestStruct) = TestStruct(x * ts.a, x * ts.b)
Base.:+(ts::TestStruct, x::Number) = TestStruct(x + ts.a, x + ts.b) 
Base.:+(x::Number, ts::TestStruct) = TestStruct(x + ts.a, x + ts.b)
Base.:+(ts1::TestStruct, ts2::TestStruct) = TestStruct(ts1.a + ts2.a, ts1.b + ts2.b)
Base.:-(ts::TestStruct, x::Number) = TestStruct(x - ts.a, x - ts.b) 
Base.:-(x::Number, ts::TestStruct) = TestStruct(x - ts.a, x - ts.b)
Base.:-(ts1::TestStruct, ts2::TestStruct) = TestStruct(ts1.a - ts2.a, ts1.b - ts2.b)

Base.zero(::Type{<:TestStruct{T1,T2}}) where {T1,T2} = TestStruct(zero(T1), zero(T2))


@testset "CellRule that multiples a struct" begin
    rule = Cell{:grid1,:grid1}() do state
         2state
    end
    init = (grid1 = fill(TS(1.0, 2.0), 5, 5),)
    output = ArrayOutput(init; tspan=1:3)
    sim!(output, rule)
    @test output[2][:grid1] == reshape([ # Have to use reshape to construct this
        TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0),
        TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0),
        TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), 
        TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), 
        TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0), TS(2.0, 4.0)
    ], (5, 5))
    @test output[3][:grid1] == reshape([ # Have to use reshape to construct this
        TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0),
        TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0),
        TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), 
        TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), 
        TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0), TS(4.0, 8.0)
    ], (5, 5))
end

@testset "Neighborhood Rule that sums a Neighborhood of stucts" begin
    rule = Neighbors{Tuple{:grid1,:grid2}, :grid1}(Moore(1)) do neighborhood, state1, state2
        sum(neighborhood) + state2
    end
    init = (
        grid1 = fill(TS(1.0, 2.0), 5, 5),
        grid2 = fill(0.5, 5, 5),
    )
    output = ArrayOutput(init; tspan=1:2)
    sim!(output, rule)
    @test output[2][:grid1] == reshape([ # Have to use reshape to construct this
        TS(3.5, 6.5),  TS(5.5, 10.5), TS(5.5, 10.5), TS(5.5, 10.5), TS(3.5, 6.5),
        TS(5.5, 10.5), TS(8.5, 16.5), TS(8.5, 16.5), TS(8.5, 16.5), TS(5.5, 10.5),
        TS(5.5, 10.5), TS(8.5, 16.5), TS(8.5, 16.5), TS(8.5, 16.5), TS(5.5, 10.5), 
        TS(5.5, 10.5), TS(8.5, 16.5), TS(8.5, 16.5), TS(8.5, 16.5), TS(5.5, 10.5), 
        TS(3.5, 6.5),  TS(5.5, 10.5), TS(5.5, 10.5), TS(5.5, 10.5), TS(3.5, 6.5)
    ], (5, 5))
end

@testset "ManualRule randomly updates a struct" begin
    rule = Manual{:grid1,:grid1}() do data, I, state
        if I == (2, 2) || I == (1, 3)
            data[:grid1][I...] = TS(99.0, 100.0)
        end
    end
    init = (grid1 = fill(TS(0.0, 0.0), 3, 3),)
    output = ArrayOutput(init; tspan=1:2)
    sim!(output, rule)
    @test output[2][:grid1] == reshape([ # Have to use reshape to construct this
        TS(0.0, 0.0), TS(0.0, 0.0), TS(0.0, 0.0), 
        TS(0.0, 0.0), TS(99.0, 100.0), TS(0.0, 0.0), 
        TS(99.0, 100.0), TS(0.0, 0.0), TS(0.0, 0.0)
    ], (3, 3))
end
