
function Base.show(io::IO, mime::MIME"text/plain", ruleset::Ruleset)
    indent = "  "
    ctx = IOContext(io, :compact => true, :indent => indent)
    printstyled(io, Base.nameof(typeof(ruleset)), "(\n"; color=:blue)
    println(io, indent * "rules = (")
    rulectx = IOContext(ctx, :indent => indent * indent)
    for rule in rules(ruleset)
        show(rulectx, mime, rule)
        print(io, ",\n")
    end
    print(io, indent * ")\n")
    _showsettings(ctx, mime, settings(ruleset))
    print(io, ")\n")
    ModelParameters.printparams(io, ruleset)
end

function Base.show(io::IO, ::MIME"text/plain", rule::T) where T<:Rule{R,W} where {R,W}
    indent = get(io, :indent, "")
    if R === :_default_ && W === :_default_
        printstyled(io, indent, Base.nameof(typeof(rule)); color=:red)
    else
        printstyled(io, indent, Base.nameof(typeof(rule)), 
                    "{", sprint(show, R), ",", sprint(show, W), "}"; color=:red)
    end
    print(io, "(")
    if !get(io, :compact, false)
        if nfields(rule) > 0
            println(io)
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
    print(io, ")")
end

function Base.show(io::IO, mime::MIME"text/plain", s::SimSettings)
    string = 
"""
SimSettings(;
$(_showsettings(io, mime, s)))
"""
    print(io, string)
end

function _showsettings(io::IO, ::MIME"text/plain", s::SimSettings)
    indent = get(io, :indent, "")
    settings = """
    $(indent)boundary = $(s.boundary),
    $(indent)proc = $(s.proc),
    $(indent)opt = $(s.opt),
    $(indent)cellsize = $(s.cellsize),
    $(indent)timestep = $(s.timestep),
    """
    print(io, settings)
end

function Base.show(io::IO, mime::MIME"text/plain", chain::Chain{R,W}) where {R,W}
    indent = get(io, :indent, "")
    ctx = IOContext(io, :compact => true, :indent => indent * "  ")
    printstyled(io, indent, string("Chain{", sprint(show, R), ",", sprint(show, W), "}"); color=:green)
    print(io, "(")
    for rule in rules(chain)
        println(io)
        show(ctx, mime, rule)
        print(io, ",")
    end
    print(io, "\n)")
end
