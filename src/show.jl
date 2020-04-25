
show(io::IO, ruleset::Ruleset) = begin
    printstyled(io, Base.nameof(typeof(ruleset)), " =\n"; color=:blue)
    println(io, "rules:")
    for rule in rules(ruleset)
        println(IOContext(io, :indent => "    "), rule)
    end
    for fn in fieldnames(typeof(ruleset))
        fn == :rules && continue
        println(io, fn, " = ", repr(getfield(ruleset, fn)))
    end
end

show(io::IO, rule::T) where T<:Rule{R,W} where {R,W} = begin
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

show(io::IO, rule::T) where T <: Map{R,W} where {R,W} = begin
    indent = get(io, :indent, "")
    printstyled(io, indent, Base.nameof(typeof(rule)),
                "{", sprint(show, R), ",", sprint(show, W), "}"; color=:red)
end

Base.show(io::IO, chain::Chain{R,W}) where {R,W} = begin
    indent = get(io, :indent, "")
    printstyled(io, indent, string("Chain{", sprint(show, R), ",", sprint(show, W), "} :"); color=:green)
    for rule in val(chain)
        println(io)
        print(IOContext(io, :indent => indent * "    "), rule)
    end
end
