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
# Date printing changed in v1.5
if VERSION >= v"1.5.0"
    @test occursin("timestep = Day(1)", sprint(show, ruleset))
end

rule1 = Cell{:a,:b}() do a
    2a
end
@test occursin("Cell{:a,:b}", sprint(show, rule1))

rule2 = Cell{Tuple{:b,:d},:c}() do b, d
    b + d
end
@test occursin("Cell{Tuple{:b,:d},:c}", sprint(show, rule2))

chain = Chain(rule1, rule2)

@test occursin("Chain{Tuple{:a,:b,:d},Tuple{:b,:c}}", sprint(show, chain))
@test occursin("    Cell{:a,:b}", sprint(show, chain))
@test occursin("    Cell{Tuple{:b,:d},:c}", sprint(show, chain))
