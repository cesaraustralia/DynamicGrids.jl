
mapinteraction!(multidata::MultiSimData, rule::Interaction) = begin
    nrows, ncols = framesize(multidata)

    # Only pass in the data that the interaction wants, in that order
    interactiondata = map(key -> multidata[key], keys(rule))

    for j in 1:ncols, i in 1:nrows
        ismasked(multidata, i, j) && continue
        state = map(d -> source(d)[i, j], interactiondata)
        newstate = applyinteraction(rule, interactiondata, state, (i, j))
        map(interactiondata, newstate) do d, s
            @inbounds dest(d)[i, j] = s
        end
    end
end

mapinteraction!(multidata::MultiSimData, rule::PartialInteraction) = begin
    # Copy the sources to dests
    map(values(data(multidata))) do d
        @inbounds parent(dest(d)) .= parent(source(d))
    end

    # Only pass in the data that the rule wants, in that order
    wkeys, wdata = writedata(rule, multidata)
    rkeys, rdata = readdata(rule, multidata)
    rd = ruledata(wkeys, wdata, rkeys, rdata)
    simdata = @set multidata.data = rd
    _interactionloop(rule, simdata, rdata, mask(multidata))

    # Update status of all arrays written to
    copystatus!(wdata)
end

_interactionloop(rule, simdata, readdata, mask) = begin
    nrows, ncols = framesize(data(simdata)[1])
    for j in 1:ncols, i in 1:nrows
        ismasked(mask, i, j) && continue
        # readstate(readdata, i, j)
        state = readstate(readdata, i, j)
        applyinteraction!(rule, simdata, state, (i, j))
    end
end

@inline readstate(data::Tuple, I...) = map(d -> readstate(d, I...), data)
@inline readstate(data, I...) = data[I...] 

@inline ruledata(wkey, wdata, rkey, rdata) = 
    ruledata((wkey,), (wdata,), (rkey,), (rdata,))
@inline ruledata(wkey, wdata, rkeys::Tuple, rdata::Tuple) = 
    ruledata((wkey,), (wdata,), rkeys, rdata)
@inline ruledata(wkeys::Tuple, wdata::Tuple, rkey, rdata) = 
    ruledata(wkeys, wdata, (rkey,), (rdata,))
@generated ruledata(wkeys::Tuple{Vararg{<:Val}}, wdata::Tuple,
                    rkeys::Tuple{Vararg{<:Val}}, rdata::Tuple) = begin
    wkeys = _vals2syms(wkeys)
    keysexp = Expr(:tuple, QuoteNode.(wkeys)...)
    dataexp = Expr(:tuple, :(wdata...))

    rkeys = _vals2syms(rkeys)
    for (i, key) in enumerate(rkeys)
        if !(key in wkeys)
            push!(dataexp.args, :(rdata[$i])) 
            push!(keysexp.args, QuoteNode(key))
        end
    end

    quote 
        NamedTuple{$keysexp}($dataexp)
    end
end

_vals2syms(x) = map(v -> v.parameters[1], x.parameters)

writedata(rule::Interaction, multidata) = writedata(writekeys(rule), multidata)
@inline writedata(keys::Tuple{Symbol,Vararg}, multidata) =
    writedata(map(Val, keys), multidata)
@inline writedata(key::Symbol, multidata) = writedata(Val(key), multidata)
writedata(keys::Tuple{Val,Vararg}, multidata) = begin
    k, d = writedata(keys[1], multidata)
    ks, ds = writedata(tail(keys), multidata)
    (k, ks...), (d, ds...)
end
writedata(keys::Tuple{}, multidata) = (), ()
writedata(key::Val{K}, multidata) where K = key, WritableSimData(multidata[K])

readdata(rule::Interaction, multidata) = readdata(readkeys(rule), multidata)
@inline readdata(keys::Tuple{Symbol,Vararg}, multidata) =
    readdata(map(Val, keys), multidata)
@inline readdata(key::Symbol, multidata) = readdata(Val(key), multidata)
readdata(keys::Tuple{Val,Vararg}, multidata) = begin
    k, d = readdata(keys[1], multidata)
    ks, ds = readdata(tail(keys), multidata)
    (k, ks...), (d, ds...)
end
readdata(keys::Tuple{}, multidata) = (), ()
readdata(key::Val{K}, multidata) where K = key, multidata[K]
