using DynamicGrids, Test, Dates
import DynamicGrids: RemoveOverflow, NoOpt

life = Life() 
@test occursin("Life{:_default_,:_default_}", sprint((io, s) -> show(io, MIME"text/plain"(), s), life))


rs = Ruleset(; 
    rules=(Life(),), 
    timestep=Day(1), 
    overflow=RemoveOverflow(),
    opt=NoOpt(),
)
@test occursin("Ruleset =", sprint((io, s) -> show(io, MIME"text/plain"(), s), rs))
@test occursin("Life{:_default_,:_default_}", sprint((io, s) -> show(io, MIME"text/plain"(), s), rs))
@test occursin(r"opt = .*NoOpt()", "nopt = DynamicGrids.NoOpt()")
@test occursin(r"overflow = .*RemoveOverflow()", sprint((io, s) -> show(io, MIME"text/plain"(), s), rs))

rule1 = Cell{:a,:b}() do a
    2a
end
@test occursin("Cell{:a,:b}", sprint((io, s) -> show(io, MIME"text/plain"(), s), rule1))

rule2 = Cell{Tuple{:b,:d},:c}() do b, d
    b + d
end
@test occursin("Cell{Tuple{:b,:d},:c}", sprint((io, s) -> show(io, MIME"text/plain"(), s), rule2))

chain = Chain(rule1, rule2)

@test occursin("Chain{Tuple{:a,:b,:d},Tuple{:b,:c}}", sprint((io, s) -> show(io, MIME"text/plain"(), s), chain))
@test occursin("    Cell{:a,:b}", sprint((io, s) -> show(io, MIME"text/plain"(), s), chain))
@test occursin("    Cell{Tuple{:b,:d},:c}", sprint((io, s) -> show(io, MIME"text/plain"(), s), chain))
