module ImageView

using Base.Graphics
import Base.show

using Color
import Images

include("config.jl")
include("display.jl")

export # types
    # display functions
    aspect,
    background,
    display,
    ftshow,
    imshow,
    perimeter,
    redraw

end
