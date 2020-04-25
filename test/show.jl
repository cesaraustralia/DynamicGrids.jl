using DynamicGrids, Test, Dates
import DynamicGrids: RemoveOverflow, NoOpt

life = Life() 
@test occursin("Life{:_default_,:_default_}", sprint(show, life))

ruleset = Ruleset(; 
    rules=(Life(),), 
    timestep=Day(1), 
    overflow=RemoveOverflow(),
    opt=NoOpt(),
)
@test occursin("Ruleset =", sprint(show, ruleset))
@test occursin("Life{:_default_,:_default_}", sprint(show, ruleset))
@test occursin(r"opt = .*NoOpt()", "nopt = DynamicGrids.NoOpt()")
@test occursin(r"overflow = .*RemoveOverflow()", sprint(show, ruleset))
@test occursin("timestep = 1 day", sprint(show, ruleset))

rule1 = Map{:a,:b}() do a
    2a
end
@test occursin("Map{:a,:b}", sprint(show, rule1))

rule2 = Map{Tuple{:b,:d},:c}() do b, d
    b + d
end
@test occursin("Map{Tuple{:b,:d},:c}", sprint(show, rule2))

chain = Chain(rule1, rule2)

@test occursin("Chain{Tuple{:a,:b,:d},Tuple{:b,:c}}", sprint(show, chain))
@test occursin("    Map{:a,:b}", sprint(show, chain))
@test occursin("    Map{Tuple{:b,:d},:c}", sprint(show, chain))
