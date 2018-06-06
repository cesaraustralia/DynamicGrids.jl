
" Runs the rule for the given model"
kernel(model::AbstractLife, args...) = rule(model, args...)

" Runs the short range rules"
kernel(model::AbstractDispersal, args...) = 
    rule(model.short, model.layers, args...)

" Runs the long range rules before the main kernel"
prekernel(model::AbstractDispersal, args...) = 
    rule(model.long, model.layers, args...)


" Rules for altering cell values "
function rule() end

rule(model::Void, args...) = nothing

"""
Rule for game-of-life style cellular automata.
"""
rule(model::AbstractLife, state, args...) = begin
    cc = neighbors(model.neighborhood, state, args...)
    cc in model.B || (state == one(state) && cc in model.S) ? one(state) : zero(state)
end

"""
Short range rule for dispersal kernels. Cells are invaded if there is pressure and 
suitable habitat, otherwise left as-is.
"""
rule(model::AbstractShortDispersal, layers, state, index, args...) = begin
    cc = neighbors(model.neighborhood, state, index, args...)
    pressure = rand() > (8 - cc) / 8 
    suitable = layer_filter(layers, index...)
    pressure && suitable ? oneunit(state) : state
end

filter_short(layers::SuitabilityLayer, row, col) = 
    layers.suitability[row, col] > zero(eltype(layers.suitability))

"""
Long range rule for dispersal kernels. Cells are invaded if there is pressure and 
suitable habitat, otherwise left as-is.
"""
rule(model::AbstractLongDispersal, layers, state, index, source, t, args...) = begin
    if state > zero(state) && rand() < model.prob
        range = -model.spotrange:model.spotrange
        spot = tuple(round.(rand(range, 2) .+ index)...)
        row, col, ok = inbounds(spot, size(source), Skip())
        if ok && layer_filter(layers, row, col) 
            source[row, col] = oneunit(state)
        end
    end
end

layer_filter(layers, row, col) = 
    layers.suitability[row, col] > zero(layers.suitability[row, col])
layer_filter(layers::Void, row, col) = true

