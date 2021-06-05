using CUDA, Setfield, StaticArrays, BenchmarkTools, DynamicGrids, Adapt, ConstructionBase, Flatten

struct AgentTracker{C,ID}
    cell::C
    id::ID
end
AgentTracker(cell::T) where T = AgentTracker(cell, typemax(T))
AgentTracker{T}() where T = AgentTracker(typemax(T), typemax(T))

cell(id::AgentTracker) = id.cell
active(id::AgentTracker{I}) where I = id.cell == typemax(I)
deactivate(id::AgentTracker{I}) where I = @set id.cell = typemax(I)
id(id::AgentTracker) = id.id
#, Inactive are sorted last
Base.isless(id1::AgentTracker, id2::AgentTracker) = isless(cell(id1), cell(id2))
Base.zero(::Type{<:AgentTracker{I,A}}) where {I,A} = AgentTracker(typemax(I), typemax(I))
Base.one(::Type{<:AgentTracker{I,A}}) where {I,A} = AgentTracker(one(I), one(A))
Base.zero(id::AgentTracker) = zero(typeof(id))
Base.one(id::AgentTracker) = one(typeof(id))

struct AgentCell
    start::Int
    count::Int
end
Base.zero(::Type{AgentCell}) = AgentCell(1, 0)
zeros(AgentCell, 100, 100)

struct AgentGrid{S,T,N,CS,CC,NC,Tr,Ag} <: StaticArray{S,T,N}
    cellstarts::CS
    cellcounts::CC
    nextcounts::NC
    trackers1::Tr
    trackers2::Tr
    agents::Ag
    count::Int
    prevcount::Int
    maxcount::Int
end
function AgentGrid{S,T,N}(
    cellstarts::CS, cellcounts::CC, nextcounts::NC, trackers1::Tr, trackers2::Tr, 
    agents::Ag, count, prevcount, maxcount
) where {S,T,N,CS,CC,NC,Tr,Ag}
    AgentGrid{S,T,N,CS,CC,NC,Tr,Ag}(
        cellstarts, cellcounts, nextcounts, trackers1, trackers2, 
        agents, count, prevcount, maxcount
    )
end
function AgentGrid(A::AbstractArray{<:AbstractArray{T}}; maxcount=n_agents(A) * 2) where T
    cellstarts = zeros(Int, size(A))
    cellcounts = zeros(Int, size(A))
    nextcounts = zeros(Int, size(A))
    agents = zeros(T, maxcount) 
    trackers1 = fill(AgentTracker{Int}(), maxcount)
    trackers2 = fill(AgentTracker{Int}(), maxcount)
    id = 0
    for i in eachindex(A)
        count = 0
        cellstarts[i] = id + 1
        for a in A[i]
            count += 1
            id += 1
            agents[id] = a
            trackers1[id] = AgentTracker(i, id)
        end
        cellcounts[i] = count
    end
    S = Tuple{size(A)...}
    T2 = typeof(view(agents, 1:0)) 
    N = ndims(A)
    AgentGrid{S,T2,N}(cellstarts, cellcounts, nextcounts, trackers1, trackers2, agents, id, id, maxcount)
end

ConstructionBase.constructorof(::Type{<:AgentGrid{S,T,N}}) where {S,T,N} = AgentGrid{S,T,N}

function Adapt.adapt_structure(T, grid::AgentGrid)
    Flatten.modify(A -> Adapt.adapt_structure(T, A), grid, Union{CuArray,Array}, Union{SArray,Function})
end

function Base.getindex(g::AgentGrid, i::Int)
    range = g.cellstarts[i]:(g.cellstarts[i] + g.cellcounts[i])
    (g.agents[g.trackers1[n].id] for n in agents_in_cell)
end

n_agents(A) = sum(length(a) for a in skipmissing(A))

# Base.parent(pop::AgentGrid) = pop.agents
# Base.size(pop::AgentGrid) = size(parent(pop))
# Base.getindex(pop::AgentGrid, I...) = getindex(parent(pop), I...)
# Base.setindex!(pop::AgentGrid, x, I...) = setindex!(parent(pop), x, I...)

abstract type AbstractAgent end
abstract type AbstractSummary end

summarise(::Type{<:AbstractAgent}, agents) = nothing

abstract type AgentRule{R,W} <: Rule{R,W} end
abstract type MultiplyRule{R,W} <: AgentRule{R,W} end
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

# struct AgentList{K} end
# AgentList(key) = AgentList{key}()

"""
    Move{A,G}

Move can either return the new location, or a
tuple of the location and the updated agent
"""
struct Move{R,W,F,ID} <: MoveRule{R,W}
    f::F
end
function applyrule(data, rule::Move, val, I)
    let data=data, rule=rule, val=val, I=I
        rule.f(data, val, I)
    end
end

summaries(neighborhood::Neighborhood) = nothing

moverule = Move{Tuple{:a,:a}}() do data, agent, I
    I .+ typeof(I)(1)
end

agentrule = Agent{Tuple{:a,:a}}() do data, agent, I
    @set! agent.age += typeof(I)(1)
end

struct MyAgent{A} <: AbstractAgent
    age::A
end
Base.one(::Type{<:MyAgent{A}}) where A = MyAgent(one(A))
Base.zero(::Type{<:MyAgent{A}}) where A = MyAgent(zero(A))

struct MyAgentsSummary <: AbstractSummary end
function summarise(::Type{<:MyAgent}, agents)
    nmales = nfemales = 0
    for agent in agents nmales += agent.male 
        nfemales += (1 - agent.male)
    end
    MyAgentsSummary(males, females)
end

Base.sort!(grid::AgentGrid) = sort!(grid.trackers1)

# inc_age(id::AgentTracker) = @set id.agent.age = id.agent.age + 1
# CUDA.allowscalar(false)
# trackers = AgentTracker.(rand(Int32, 500_000))
# trackers = ((t, id) -> @set a.id = id).(trackers, 1:length(trackers))
# agents = [zero(MyAgent{Int32}) for i in eachindex(ids)]
# pop = AgentList(ids, agents, 100, 100, 100);
# cupop = @set pop.agents = CuArray(pop.agents)

# @time sort!(pop.ids);
# CUDA.@time sort!(cupop.ids);
# @time partialsort!(pop.ids, 1:length(pop.ids) ÷ 10)
# CUDA.@time partialsort!(pop.ids, 1:length(pop.ids) ÷ 10)



function runsomerules(grid, rule1, rule2)
    grid.nextcounts .= 0
    applyrule!.(Ref(grid), Ref(rule1), range)
    applyrule!.(Ref(grid), Ref(rule2), range)
end

import DynamicGrids: maprule!, applyrule, applyrule!, cell_kernel!

function maprule!(grid, ruletype::Val{<:AgentRule}, rule)
    # rkeys, _ = _getreadgrids(rule, data)
    # wkeys, _ = _getwritegrids(rule, data)
    grid.cellcounts .= grid.nextcounts
    range = Base.OneTo(grid.count)
    cell_kernel!.(Ref(RuleData(data)), Ref(ruletype), Ref(rule), range)
    count = 0
    return grid
end

function maprule!(grid, ruletype::Val{<:MoveRule}, rule)
    # rkeys, _ = _getreadgrids(rule, data)
    # wkeys, _ = _getwritegrids(rule, data)
    grid.cellcounts .= grid.nextcounts
    range = Base.OneTo(grid.count)
    cell_kernel!.(Ref(RuleData(data)), Ref(ruletype), Ref(rule), range)
    count = 0
    for i in eachindex(grid.cellcounts)
        count += grid.cellcounts[i]
        grid.nextcounts[i] = count
    end
    for i in range
        t = grid.trackers1[i]
        cell = t.cell
        pos = grid.nextcounts[cell]
        grid.trackers2[pos] = t
    end
    return grid
end

function DynamicGrids.cell_kernel!(g, ruletype::Val{<:MoveRule}, rule, i)
    t = g.trackers1[i]
    dest = applyrule(nothing, rule2, g.agents[t.id], t.cell)
    dest = dest > length(g.nextcounts) ? t.cell : dest
    g.nextcounts[dest] += 1 
    g.trackers1[i] = @set t.cell = dest 
end

function DynamicGrids.cell_kernel!(g, rule, ruletype::Val{<:AgentRule}, i)
    t = g.trackers1[i]
    g.agents[t.id] = applyrule(g, rule1, g.agents[t.id], t.cell)
end


S = 500
agentgrid = [[zero(MyAgent{Int}) for a in 1:rand(0:10)] for I in CartesianIndices((S, S))]
n_agents(agentgrid)
grid = AgentGrid(agentgrid);
runsomerules(grid, agentrule, moverule)
culist = Adapt.adapt(CuArray, grid)
typeof(grid)

# Simulate running 2 rules over 100 frames
@time for i in 1:100 runsomerules(grid, agentrule, moverule) end
# CUDA.@time for i in 1:100 runsomerules(culist, agentrule, moverule) end
