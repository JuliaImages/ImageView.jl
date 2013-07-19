include(joinpath(Pkg.dir(),"ImageView","test","testimages.jl"))

module ImageView

using Base.Graphics
# import Base.show

using Color
using Tk
using Cairo
using Images

include("config.jl")
include("external.jl")
include("rubberband.jl")
include("navigation.jl")
include("contrast.jl")
include("display.jl")

export # types
    # display functions
#     aspect,
#     background,
    canvas,
    canvasgrid,
    display,
    ftshow,
    imshow
#     perimeter,
#     redraw

end
