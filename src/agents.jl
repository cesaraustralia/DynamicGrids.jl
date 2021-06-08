using CUDA, Setfield, StaticArrays, BenchmarkTools, DynamicGrids, Adapt, ConstructionBase, Flatten

import DynamicGrids: maprule!, applyrule, applyrule!, cell_kernel!, ruletype

struct AgentTracker{A,C,ID}
    agent::A
    cell::C
    id::ID
end

agent(tr::AgentTracker) = tr.agent
cell(tr::AgentTracker) = tr.cell
id(tr::AgentTracker) = tr.id
isactive(tr::AgentTracker{I}) where I = tr.cell == typemax(I)
deactivate(tr::AgentTracker{I}) where I = @set tr.cell = typemax(I)
#, Inactive are sorted last
Base.isless(id1::AgentTracker, id2::AgentTracker) = isless(cell(id1), cell(id2))
Base.zero(::Type{<:AgentTracker{A,C,ID}}) where {A,C,ID} = AgentTracker(zero(A), typemax(C), typemax(ID))
Base.one(::Type{<:AgentTracker{A,C,ID}}) where {A,C,ID} = AgentTracker(one(A), one(C), one(ID))
Base.zero(tr::AgentTracker) = zero(typeof(tr))
Base.one(tr::AgentTracker) = one(typeof(tr))

struct AgentCell
    start::Int
    count::Int
end
Base.zero(::Type{AgentCell}) = AgentCell(1, 0)

struct AgentGrid{S,T,N,Sc,Dt,ScC,DtC,CS,Co,IDCo} <: StaticArray{S,T,N}
    source::Sc
    dest::Dt
    sourcecounts::ScC
    destcounts::DtC
    cellstarts::CS
    count::Co
    idcount::IDCo
    maxcount::Int
end
function AgentGrid{S,T,N}(
    source::Sc, dest::Dt, sourcecounts::ScC, destcounts::DtC, 
    cellstarts::CS, count::Co, idcount::IDCo, maxcount
) where {S,T,N,Sc,Dt,ScC,DtC,CS,Co,IDCo}
    AgentGrid{S,T,N,Sc,Dt,ScC,DtC,CS,Co,IDCo}(
        source, dest, sourcecounts, destcounts, cellstarts, count, idcount, maxcount
    )
end
function AgentGrid(A::AbstractArray{<:AbstractArray{T}}; maxcount=n_agents(A) * 2) where T
    source = zeros(AgentTracker{T,Int,Int}, maxcount)
    dest = zeros(AgentTracker{T,Int,Int}, maxcount)
    sourcecounts = zeros(Int, size(A))
    destcounts = zeros(Int, size(A))
    cellstarts = zeros(Int, size(A))
    id = 0
    for i in eachindex(A)
        count = 0
        cellstarts[i] = id + 1
        for a in A[i]
            count += 1
            id += 1
            source[id] = AgentTracker(a, i, id)
        end
        sourcecounts[i] = count
    end
    S = Tuple{size(A)...}
    T2 = typeof(view(source, 1:0))
    N = ndims(A)
    AgentGrid{S,T2,N}(source, dest, sourcecounts, destcounts, cellstarts, fill(id), fill(id), maxcount)
end

ConstructionBase.constructorof(::Type{<:AgentGrid{S,T,N}}) where {S,T,N} = AgentGrid{S,T,N}

function Adapt.adapt_structure(T, grid::AgentGrid)
    Flatten.modify(A -> Adapt.adapt_structure(T, A), grid, Union{CuArray,Array}, Union{SArray,Function})
end

function Base.getindex(g::AgentGrid, i::Int)
    range = g.cellstarts[i]:(g.cellstarts[i] + g.sourcecounts[i])
    (g.source[n].agent for n in range)
end

n_agents(A) = sum(length(a) for a in skipmissing(A))

# Base.parent(pop::AgentGrid) = pop.source
# Base.size(pop::AgentGrid) = size(parent(pop))
# Base.getindex(pop::AgentGrid, I...) = getindex(parent(pop), I...)
# Base.setindex!(pop::AgentGrid, x, I...) = setindex!(parent(pop), x, I...)

abstract type AbstractAgent end
abstract type AbstractSummary end

summarise(::Type{<:AbstractAgent}, agents) = nothing

abstract type AgentRule{R,W} <: Rule{R,W} end
abstract type ReproduceRule{R,W} <: AgentRule{R,W} end
abstract type MoveRule{R,W} <: AgentRule{R,W} end
abstract type UpdateAgentRule{R,W} <: AgentRule{R,W} end

struct Agent{R,W,F,ID} <: UpdateAgentRule{R,W}
    f::F
end
function applyrule(data, rule::Agent, val, I)
    let data=data, rule=rule, val=val, I=I
        rule.f(data, val, I)
    end
end

struct Summary{K,F} <: ParameterSource end
Summary(key, field=nothing) = Summary{key,field}()

"""
    Move <: MoveRule

    Move(f)

Move can either return the new location, or a
tuple of the location and the updated agent
"""
struct Move{R,W,F} <: MoveRule{R,W}
    f::F
end
function applyrule(data, rule::Move, val, I)
    let data=data, rule=rule, val=val, I=I
        rule.f(data, val, I)
    end
end

"""
    Reproduce <: ReproduceRule

    Reproduce(f)

Add or remove population
"""
struct Reproduce{R,W,F} <: ReproduceRule{R,W}
    f::F
end
function applyrule!(data, rule::Reproduce, val, I)
    let data=data, rule=rule, val=val, I=I
        rule.f(data, val, I)
    end
end

summaries(neighborhood::Neighborhood) = nothing

struct MyAgent{A} <: AbstractAgent
    age::A
end
Base.one(::Type{<:MyAgent{A}}) where A = MyAgent(one(A))
Base.one(a::MyAgent) = one(typeof(a))
Base.zero(::Type{<:MyAgent{A}}) where A = MyAgent(zero(A))
Base.zero(a::MyAgent) = zero(typeof(a))

struct MyAgentsSummary <: AbstractSummary end
function summarise(::Type{<:MyAgent}, agents)
    nmales = nfemales = 0
    for agent in agents nmales += agent.male 
        nfemales += (1 - agent.male)
    end
    MyAgentsSummary(males, females)
end

function maprule!(grid, ruletype::Val{<:AgentRule}, rule)
    # rkeys, _ = _getreadgrids(rule, data)
    # wkeys, _ = _getwritegrids(rule, data)
    grid.destcounts .= 0
    range = Base.OneTo(grid.count[])
    agent_kernel!.(Ref(grid), Ref(ruletype), Ref(rule), range)
    grid.sourcecounts .= grid.destcounts
    count = 0
    return grid
end

DynamicGrids.ruletype(::AgentRule) = AgentRule
DynamicGrids.ruletype(::MoveRule) = MoveRule
DynamicGrids.ruletype(::ReproduceRule) = ReproduceRule

maprule!(grid, rule::AgentRule) = maprule!(grid, Val{ruletype(rule)}(), rule)
function maprule!(grid, ruletype::Val{<:MoveRule}, rule)
    # rkeys, _ = _getreadgrids(rule, data)
    # wkeys, _ = _getwritegrids(rule, data)
    range = Base.OneTo(grid.count[])
    grid.destcounts .= 0
    agent_kernel!.(Ref(grid), Ref(ruletype), Ref(rule), range)
    count_buffer = grid.sourcecounts
    count_buffer .= 0
    count = 0
    for i in eachindex(grid.destcounts)
        count += grid.destcounts[i]
        count_buffer[i] = count
    end
    for i in range
        t = grid.dest[i]
        cell = t.cell
        pos = count_buffer[cell]
        count_buffer[cell] -= 1
        grid.source[pos] = t
    end
    grid.source .= grid.dest
    grid.sourcecounts .= grid.destcounts
    return grid
end

function agent_kernel!(g, ruletype::Val{<:MoveRule}, rule, n)
    t = g.source[n]
    I = applyrule(g, rule, t.agent, t.cell)
    I = (I > length(g.destcounts) || I < 1) ? t.cell : I
    g.destcounts[I] += 1 # TODO: use atomics
    g.dest[n] = @set t.cell = I
    nothing
end

function agent_kernel!(g, ruletype::Val{<:ReproduceRule}, rule, i)
    t = g.source[i]
    applyrule!(g, rule, t.agent, t.cell)
    nothing
end

function agent_kernel!(g, ruletype::Val{<:AgentRule}, rule, i)
    t = g.source[i]
    a = applyrule(g, rule, t.agent, t.cell)
    t = g.source[i] = @set t.agent = a
    nothing
end

function new!(grid, agent, cell)
    id = grid.idcount[] + 1
    count = grid.count[] + 1
    count <= grid.maxcount || _exceed_maxcount_error(grid.maxcount)

    tr = AgentTracker(agent, cell, id) 
    grid.source[count] = tr
    grid.sourcecounts[cell] += 1   

    grid.idcount[] = id
    grid.count[] = count
end

@noinline _exceed_maxcount_error(maxcount) = error("Agents exceed maxcount: $maxcount")

function rem!(grid, agent)
    grid.dest[agent.cell] = zero(AgentTracker)
    grid.destcounts[agent.cell] -= 1   
end


# Scripts

moverule = Move{Tuple{:a,:a}}() do data, agent, I
    I .+ typeof(I)(1)
end

reprule = Reproduce{Tuple{:a,:a}}() do data, agent, I
    if rand() < 0.01
        new!(data, zero(agent), I)
    end
    return nothing
end

agentrule = Agent{Tuple{:a,:a}}() do data, agent, I
    @set! agent.age += typeof(I)(1)
end

S = 500
agentgrid = [[zero(MyAgent{Int}) for a in 1:rand(0:5)] for I in CartesianIndices((S, S))];
n_agents(agentgrid)
grid = AgentGrid(agentgrid; maxcount=5_000_000);
maprule!(grid, reprule);

# Simulate running 2 rules over 100 frames
@time for i in 1:100 maprule!(grid, reprule) end
# CUDA.@time for i in 1:100 runsomerules(culist, agentrule, moverule) end
