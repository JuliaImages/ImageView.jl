(Sys.islinux() || Sys.iswindows()) && import ImageMagick # work around libz issues
using ImageView
using Images, OffsetArrays
using Gtk
using Test

if !isdefined(@__MODULE__, :imshow_now)
    function imshow_now(args...; kwargs...)
        @nospecialize
        guidict = imshow(args...; kwargs...)
        Gtk.showall(guidict["gui"]["window"])
        sleep(0.01)
        guidict
    end
end

include("simple.jl")
include("contrast.jl")
include("contrast_kwargs.jl")
include("scalesigned.jl")
include("tile.jl")
include("annotations.jl")
include("statusbar.jl")
include("test4d.jl")
imshow(img)

include("newtests.jl")

ImageView.closeall()
