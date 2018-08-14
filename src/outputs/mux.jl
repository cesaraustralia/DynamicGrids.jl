
@Frames mutable struct MuxServer{F} <: AbstractWebOutput{T}
    fps::F
    port::Int
end

MuxServer(frames::T, model; fps=25, port=8000) where T <: AbstractVector = begin
    server = MuxServer(frames, fps, port)
    function muxapp(req)
        WebInterface(deepcopy(server.frames), server.fps, model).page
    end
    webio_serve(page("/", req -> muxapp(req)), port)
    server
end
