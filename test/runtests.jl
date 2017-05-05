include("simple.jl")
include("scalesigned.jl")
include("tile.jl")
include("annotations.jl")
include("statusbar.jl")
include("test4d.jl")
ImageView.imshow(img)

include("newtests.jl")

ImageView.closeall()
