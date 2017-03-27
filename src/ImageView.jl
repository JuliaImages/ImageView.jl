__precompile__(false)

module ImageView

using Graphics
import Graphics: width, height, fill, set_coordinates, xmin, xmax, ymin, ymax

using FileIO
using Cairo
using Tk
using Colors
using Images, AxisArrays

import Base: parent, show, delete!, empty!

hasaxes(img) = hasaxes(AxisArrays.HasAxes(img))
hasaxes(::AxisArrays.HasAxes{true})  = true
hasaxes(::AxisArrays.HasAxes{false}) = false

# include("config.jl")
# include("external.jl")
include("rubberband.jl")
include("annotations.jl")
include("navigation.jl")
include("contrast.jl")
include("display.jl")

export # types
    AnnotationPoint,
    AnnotationPoints,
    AnnotationLine,
    AnnotationLines,
    AnnotationBox,
    AnnotationText,
    AnnotationScalebarFixed,
    # display functions
    annotate!,
    canvas,
    canvasgrid,
    delete_annotations!,
    destroy,
#     ftshow,
    imshow,
    imshowlabeled,
    parent,
    scalebar,
    toplevel,
    write_to_png

@deprecate view imshow
@deprecate viewlabeled imshowlabeled

end
