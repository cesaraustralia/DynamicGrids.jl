# See interface docs
@inline inbounds(xs::Tuple, data::Union{GridData,SimData}) = 
    inbounds(xs, gridsize(data), boundary(data))
@inline function inbounds(xs::Tuple, maxs::Tuple, boundary)
    a, inbounds_a = inbounds(xs[1], maxs[1], boundary)
    b, inbounds_b = inbounds(xs[2], maxs[2], boundary)
    (a, b), inbounds_a & inbounds_b
end
@inline function inbounds(x::Number, max::Number, boundary::Remove)
    x, isinbounds(x, max)
end
@inline function inbounds(x::Number, max::Number, boundary::Wrap)
    if x < oneunit(x)
        max + rem(x, max), true
    elseif x > max
        rem(x, max), true
    else
        x, true
    end
end

@inline isinbounds(x::Tuple, data::Union{SimData,GridData}) =
    isinbounds(x::Tuple, gridsize(data))
@inline isinbounds(xs::Tuple, maxs::Tuple) = all(isinbounds.(xs, maxs))

@inline isinbounds(x::Number, max::Number) = x >= one(x) && x <= max


#= Wrap boundary where required. This optimisation allows us to ignore
bounds checks on neighborhoods and still use a wraparound grid. =#
_handleboundary!(grids::Tuple) = map(_handleboundary!, grids)
_handleboundary!(griddata::GridData) = _handleboundary!(griddata, boundary(griddata))
_handleboundary!(griddata::GridData, ::Remove) = griddata
function _handleboundary!(griddata::GridData, ::Wrap)
    r = radius(griddata)
    r < 1 && return griddata

    # TODO optimise this. Its mostly a placeholder so wrapping still works in GOL tests.
    src = parent(source(griddata))
    nrows, ncols = gridsize(griddata)
    startpadrow = startpadcol = 1:r
    endpadrow = nrows+r+1:nrows+2r
    endpadcol = ncols+r+1:ncols+2r
    startrow = startcol = 1+r:2r
    endrow = nrows+1:nrows+r
    endcol = ncols+1:ncols+r
    rows = 1+r:nrows+r
    cols = 1+r:ncols+r

    # Left
    @inbounds copyto!(src, CartesianIndices((rows, startpadcol)),
                      src, CartesianIndices((rows, endcol)))
    # Right
    @inbounds copyto!(src, CartesianIndices((rows, endpadcol)),
                      src, CartesianIndices((rows, startcol)))
    # Top
    @inbounds copyto!(src, CartesianIndices((startpadrow, cols)),
                      src, CartesianIndices((endrow, cols)))
    # Bottom
    @inbounds copyto!(src, CartesianIndices((endpadrow, cols)),
                      src, CartesianIndices((startrow, cols)))

    # Copy four corners
    # Top Left
    @inbounds copyto!(src, CartesianIndices((startpadrow, startpadcol)),
                      src, CartesianIndices((endrow, endcol)))
    # Top Right
    @inbounds copyto!(src, CartesianIndices((startpadrow, endpadcol)),
                      src, CartesianIndices((endrow, startcol)))
    # Botom Left
    @inbounds copyto!(src, CartesianIndices((endpadrow, startpadcol)),
                      src, CartesianIndices((startrow, endcol)))
    # Botom Right
    @inbounds copyto!(src, CartesianIndices((endpadrow, endpadcol)),
                      src, CartesianIndices((startrow, startcol)))

    _wrapstatus!(sourcestatus(griddata))
end

_wrapstatus!(status::Nothing) = nothing
function _wrapstatus!(status::AbstractArray)
    # This could be further optimised.
    status[end-1, :] .|= status[1, :]
    status[:, end-1] .|= status[:, 1]
    #status[end-2, :] .|= status[1, :] .|= status[2, :]
    status[end-2, :] .= true
    status[:, end-2] .|= status[:, 1] .|= status[:, 2]
    #status[1, :] .|= status[end-2, :] .|= status[end-1, :]
    status[1, :] .= true
    status[:, 1] .|= status[:, end-2] .|= status[:, end-1]
    status .= true
end
