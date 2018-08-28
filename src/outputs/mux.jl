using Mux

@Frames mutable struct MuxServer{F} <: AbstractWebOutput{T}
    fps::F
    port::Int
end

MuxServer(frames::T, model, args...; fps=25, port=8080) where T <: AbstractVector = begin
    server = MuxServer(frames, fps, port)
    function muxapp(req)
        WebInterface(deepcopy(server.frames), server.fps, deepcopy(model), args...).page
    end
    webio_serve(page("/", req -> muxapp(req)), port)
    server
end
