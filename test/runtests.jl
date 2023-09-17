using ImageView
using ImageCore, OffsetArrays
using Gtk4
using Test

Gtk4.GLib.start_main_loop()

if !isdefined(@__MODULE__, :imshow_now)
    function imshow_now(args...; kwargs...)
        @nospecialize
        guidict = imshow(args...; kwargs...)
        sleep(0.01)
        guidict
    end
end

include("core.jl")
include("simple.jl")
include("contrast.jl")
include("kwargs.jl")
include("scalesigned.jl")
include("tile.jl")
include("annotations.jl")
include("statusbar.jl")
include("test4d.jl")
imshow(img)

include("newtests.jl")

ImageView.closeall()
