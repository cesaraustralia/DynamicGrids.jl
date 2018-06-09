"""
Checks all cells in neighborhood and sums them according
to the particular neighborhood rule.
"""
function neighbors() end

neighbors(h::RadialNeighborhood{:onedim}, state, index, source, args...) = begin
    width = size(source)
    r = h.radius
    cc = -source[index]
    for p = (index - r):(index + r)
        p = bounded(p, width, n.overflow)
        cc += source[p]
    end
    cc
end

neighbors(h::RadialNeighborhood, state, index, source, args...) = begin
    height, width = size(source)
    row, col = index
    r = h.radius
    cc = -source[row, col]
    for q = (col - r):(col + r)
        for p = (row - r):(row + r)
            inhood(h, p, q, row, col) || continue
            p, q, inb = inbounds((p, q), (height, width), h.overflow) 
            inb || continue
            cc += source[p, q]
        end
    end
    cc
end

neighbors(h::DispersalNeighborhood, state, index, source, args...) = begin
    height, width = size(source)
    row, col = index
    r = div(size(h.dispkernel, 1) - 1, 2)
    cc = 0.0
    # loop over dispersal kernel grid dimensions
    for a = -r:r 
        for b = -r:r
            # ignore the current cell?
            a == 0 && b == 0 && continue
            p, q, inb = inbounds((row + b, col + a), (height, width), h.overflow)
            inb || continue
            cc += source[p, q] * h.dispkernel[a + r + 1, b + r + 1]
        end
    end
    return cc
end

neighbors(h::SingleCustomNeighborhood, state, index, source, args...) =
    custom_neighbors(h.neighborhood, h, index, source, args...)

neighbors(h::MultiCustomNeighborhood, state, index, source, args...) = begin
    for i = 1:length(h.multineighbors)
        mn.cc[i] = custom_neighbors(h.multineighbors[i], h, index, source)
    end
    mn.cc
end

custom_neighbors(n::AbstractArray, h, index, source) = begin
    height, width = size(source)
    row, col = index
    cc = zero(eltype(source))
    for (a, b) in n
        p, q = inbounds((a + row, b + col), (height, width), n.overflow) || continue
        cc += source[p, q]
    end
    cc
end

" Check radial neighborhood pattern, return a boolean "
inhood(n::RadialNeighborhood{:moore}, p, q, row, col) = true
inhood(n::RadialNeighborhood{:vonneumann}, p, q, row, col) = 
    (abs(p - row) + abs(q - col)) <= n.radius
inhood(n::RadialNeighborhood{:rotvonneumann}, p, q, row, col) = 
    (abs(p - row) + abs(q - col)) > n.radius

""" 
Check grid boundaries. 
returns a 3-tuple of coords and a boolean 
"""
inbounds(xs::Tuple, maxs::Tuple, overflow) = begin
    a, inbounds_a = inbounds(xs[1], maxs[1], overflow)
    b, inbounds_b = inbounds(xs[2], maxs[2], overflow)
    a, b, inbounds_a && inbounds_b
end
inbounds(x::Number, max::Number, overflow::Skip) = x, x > 0 && x < max
inbounds(x::Number, max::Number, overflow::Wrap) = begin
    if x < 1 
        x = max + x 
    elseif x > max 
        x = x - max 
    end
    x, true
end
