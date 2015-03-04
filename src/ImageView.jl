module ImageView

if VERSION < v"0.4.0-dev+3275"
    using Base.Graphics
    import Base.Graphics: width, height, fill, set_coords, xmin, xmax, ymin, ymax
else
    using Graphics
    import Graphics: width, height, fill, set_coords, xmin, xmax, ymin, ymax
end

using Cairo
using Tk
using Color
using Images
using Compat

import Base: parent, show, delete!, empty!

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
#     imshow,
    parent,
    scalebar,
    toplevel,
    view,
    viewlabeled,
    write_to_png

@deprecate delete_annotations! empty!
@deprecate delete_annotation! delete!
@deprecate display(c::Canvas, img::AbstractArray; proplist...) view(c, img; proplist...)
@deprecate display(imgc::ImageCanvas, img::AbstractArray; proplist...) view(imgc, img; proplist...)
@deprecate display(img::AbstractArray; proplist...) view(img; proplist...)

end
