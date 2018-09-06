using Mux

"""
A basic Mux.jl webserver, serving identical pages to BlinkOutput
"""
@Frames mutable struct MuxServer{F} <: AbstractWebOutput{T}
    fps::F
    port::Int
end


"""
    MuxServer(frames, model, args...; fps=25, port=8080)
Builds a MuxServer and serves the standard web interface for model
simulations at the chosen port. 

### Arguments
- `frames::AbstractArray`: vector of matrices.
- `model::Models`: tuple of models wrapped in Models().
- `args`: any additional arguments to be passed to the model rule

### Keyword arguments
- `fps`: frames per second
- `showmax_fps`: maximum displayed frames per second
- `port`: port number to reach the server at
"""
MuxServer(frames::T, model, args...; fps=25, showmax_fps=25, port=8080) where T <: AbstractVector = begin
    server = MuxServer(frames, fps, port)
    function muxapp(req)
        WebInterface(deepcopy(server.frames), server.fps, false, deepcopy(model), args...).page
    end
    webio_serve(page("/", req -> muxapp(req)), port)
    server
end
