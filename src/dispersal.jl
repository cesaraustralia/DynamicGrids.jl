
DispersalNeighborhood(; f = d -> exponential(d, 1), radius = 3, 
                      overflow = Skip()) = begin
    dispkernel = build_dispersal_kernel(f, radius) 
    DispersalNeighborhood(dispkernel, overflow)
end

build_dispersal_kernel(f, r) = begin
    size = 2r + 1
    grid = zeros(Float64, size, size)
    for i = -r:r, j = -r:r
        d = sqrt(i^2 + j^2) 
        grid[i + r + 1, j + r + 1] = f(d) 
    end
    grid
end

exponential(d, a) = e^-d * a

# more dipersal kernel functions here

