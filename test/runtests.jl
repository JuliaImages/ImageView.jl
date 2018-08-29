using ImageView
using Images, OffsetArrays
using Base.Test

function imshow_now(args...; kwargs...)
    guidict = imshow(args...; kwargs...)
    Gtk.showall(guidict["gui"]["window"])
    sleep(0.01)
    guidict
end

include("simple.jl")
include("contrast.jl")
include("scalesigned.jl")
include("tile.jl")
include("annotations.jl")
include("statusbar.jl")
include("test4d.jl")
imshow(img)

include("newtests.jl")

ImageView.closeall()
