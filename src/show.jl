
function Base.show(io::IO, ::MIME"text/plain", ruleset::Ruleset)
    printstyled(io, Base.nameof(typeof(ruleset)), " =\n"; color=:blue)
    println(io, "rules:")
    for rule in rules(ruleset)
        print(io, _showrule(io, rule))
    end
    for fn in fieldnames(typeof(ruleset))
        fn == :rules && continue
        println(io, fn, " = ", repr(getfield(ruleset, fn)))
    end
    ModelParameters.printparams(io, ruleset)
end

function Base.show(io::IO, ::MIME"text/plain", rule::T) where T<:Rule{R,W} where {R,W}
    indent = get(io, :indent, "")
    printstyled(io, indent, Base.nameof(typeof(rule)), 
                "{", sprint(show, R), ",", sprint(show, W), "}"; color=:red)
    if nfields(rule) > 0
        printstyled(io, " :\n"; color=:red)
        for fn in fieldnames(T)
            if fieldtype(T, fn) <: Union{Number,Symbol,String}
                println(io, indent, "    ", fn, " = ", repr(getfield(rule, fn)))
            else
                # Avoid prining arrays etc. Just show the type.
                println(io, indent, "    ", fn, " = ", fieldtype(T, fn))
            end
        end
    end
end

function Base.show(io::IO, ::MIME"text/plain", chain::Chain{R,W}) where {R,W}
    indent = get(io, :indent, "")
    printstyled(io, indent, string("Chain{", sprint(show, R), ",", sprint(show, W), "} :"); color=:green)
    for rule in rules(chain)
        println(io)
        print(io, _showrule(io, rule, indent))
    end
end

_showrule(io, rule, indent="") =
    sprint((io, x) -> show(IOContext(io, :indent => indent * "    "), MIME"text/plain"(), x), rule)
