using CUDA, Setfield, BenchmarkTools, DynamicGrids, Adapt

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

struct AgentList{T,A}
    trackers::T
    agents::A
    count::Int
    prevcount::Int
    maxcount::Int
end
function AgentList(A::AbstractArray{<:AbstractArray{T}}; maxcount=n_agents(A) * 2) where T
    agents = zeros(T, maxcount) 
    trackers = fill(AgentTracker{Int}(), maxcount)
    id = 0
    for cell in eachindex(A)
        for a in A[cell]
            id += 1
            agents[id] = a
            trackers[id] = AgentTracker(cell, id)
        end
    end
    @show "count", id
    AgentList(trackers, agents, id, id, maxcount)
end
function Adapt.adapt_structure(T, list::AgentList)
    @set! list.trackers = Adapt.adapt_structure(T, list.trackers)
    @set list.agents = Adapt.adapt_structure(T, list.agents)
end

n_agents(A) = sum(length(a) for a in skipmissing(A))

Base.parent(pop::AgentList) = pop.agents
Base.size(pop::AgentList) = size(parent(pop))
Base.getindex(pop::AgentList, I...) = getindex(parent(pop), I...)
Base.setindex!(pop::AgentList, x, I...) = setindex!(parent(pop), x, I...)

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
    for agent in agents
        nmales += agent.male
        nfemales += (1 - agent.male)
    end
    MyAgentsSummary(males, females)
end

function runsomerules(agentlist, rule1, rule2)
    trackers = agentlist.trackers
    agents = agentlist.agents
    range = 1:agentlist.count 
    applyrules!.(Ref(trackers), Ref(agents), range, Ref(rule1), Ref(rule2))
    sort!(trackers);
end

function applyrules!(trackers, agents, i, rule1, rule2)
    t = trackers[i]
    agents[t.id] = applyrule(nothing, rule1, agents[t.id], t.cell)
    trackers[i] = @set t.cell = applyrule(nothing, rule2, agents[t.id], t.cell)
end

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

S = 500
agentgrid = [[zero(MyAgent{Int}) for a in 1:rand(0:10)] for I in CartesianIndices((S, S))]
n_agents(agentgrid)
list = AgentList(agentgrid)
runsomerules(list, agentrule, moverule)
culist = Adapt.adapt(CuArray, list)

# Simulate running 2 rules over 100 frames
@time for i in 1:100 runsomerules(list, agentrule, moverule) end
Adapt.@time for i in 1:100 runsomerules(culist, agentrule, moverule) end
