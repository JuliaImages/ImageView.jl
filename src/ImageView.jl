__precompile__()

module ImageView

using FixedPointNumbers, Colors, ColorVectorSpace, Images, StatsBase
using MappedArrays, AxisArrays, RoundingIntegers
using Gtk.ShortNames, GtkReactive, Graphics
using Compat
using Gtk.GConstants.GtkAlign: GTK_ALIGN_START, GTK_ALIGN_END, GTK_ALIGN_FILL

export AnnotationText, AnnotationPoint, AnnotationPoints,
       AnnotationLine, AnnotationLines, AnnotationBox
export CLim, annotate!, canvasgrid, imshow, imshow_gui, imlink,
       roi, scalebar, slice2d

const AbstractGray{T} = Color{T,1}
const GrayLike = Union{AbstractGray,Number}
const FixedColorant{T<:FixedPoint} = Colorant{T}

include("slicing.jl")

"""
    CLim(cmin, cmax)

Specify contrast limits where `x <= cmin` will be rendered as black,
and `x >= cmax` will be rendered as white.
"""
struct CLim{T}
    min::T
    max::T
end
CLim(min, max) = CLim(promote(min, max)...)
Base.convert(::Type{CLim{T}}, clim::CLim) where {T} = CLim(convert(T, clim.min),
                                                    convert(T, clim.max))
Base.eltype(::CLim{T}) where {T} = T

"""
    closeall()

Closes all windows opened by ImageView2.
"""
function closeall()
    for (w, _) in window_wrefs
        destroy(w)
    end
    nothing
end

const window_wrefs = WeakKeyDict{Gtk.GtkWindowLeaf,Void}()

"""
    imshow()

Choose an image to display via a file dialog.
"""
imshow() = imshow(load(open_dialog("Pick an image to display")))

"""
    imshow!(canvas, img) -> drawsignal
    imshow!(canvas, img::Signal, zr::Signal{ZoomRegion}) -> drawsignal
    imshow!(frame::Frame, canvas, img::Signal, zr::Signal{ZoomRegion}) -> drawsignal

Display the image `img`, in the specified `canvas`. Use the version
with `zr` if you have already turned on rubber-banding or other
pan/zoom interactivity for `canvas`. Returns the Reactive `drawsignal`
used for updating the canvas.

If you supply `frame`, then the pixel aspect ratio will be set to that
of `pixelspacing(img)`.

This only creates the `draw` method for `canvas`; mouse- or key-based
interactivity can be set up via [`imshow`](@ref) or, at a lower level,
using GtkReactive's tools:

- `init_zoom_rubberband`
- `init_zoom_scroll`
- `init_pan_scroll`
- `init_pan_drag`
"""
function imshow!(canvas::GtkReactive.Canvas{UserUnit},
                 imgsig::Signal,
                 zr::Signal{ZoomRegion{T}},
                 annotations::Signal{Dict{UInt,Any}}) where T<:RInteger
    draw(canvas, imgsig, anns) do cnvs, image, anns
        copy!(cnvs, image)
        set_coordinates(cnvs, value(zr))
        draw_annotations(cnvs, anns)
    end
end

function imshow!(frame::Frame,
                 canvas::GtkReactive.Canvas{UserUnit},
                 imgsig::Signal,
                 zr::Signal{ZoomRegion{T}},
                 annotations::Signal{Dict{UInt,Any}}) where T<:RInteger
    draw(canvas, imgsig, annotations) do cnvs, image, anns
        copy!(cnvs, image)
        set_coordinates(cnvs, value(zr))
        set_aspect!(frame, image)
        draw_annotations(cnvs, anns)
    end
end

# Without a ZoomRegion, there's no risk that the apsect ratio needs to
# change dynamically, so it can be set once and left. Consequently we
# don't need `frame` variants of the remaining methods.
function imshow!(canvas::GtkReactive.Canvas,
                 imgsig::Signal,
                 annotations::Signal{Dict{UInt,Any}})
    draw(canvas, imgsig, annotations) do cnvs, image, anns
        copy!(cnvs, image)
        set_coordinates(cnvs, indices(image))
        draw_annotations(cnvs, anns)
    end
end

# Simple non-interactive image display
function imshow!(canvas::GtkReactive.Canvas,
                 img::AbstractMatrix,
                 annotations::Signal{Dict{UInt,Any}})
    draw(canvas, annotations) do cnvs, anns
        copy!(cnvs, img)
        set_coordinates(cnvs, indices(img))
        draw_annotations(cnvs, anns)
    end
    nothing
end

"""
    imshow(img; axes=(1,2), name="ImageView") -> guidict
    imshow(img, clim; axes=(1,2), name="ImageView") -> guidict
    imshow(img, clim, zoomregion, slicedata, annotations; axes=(1,2), name="ImageView") -> guidict

Display the image `img` in a new window titled with `name`, returning
a dictionary `guidict` containing any Reactive signals or GtkReactive
widgets. If the image is 3 or 4 dimensional, GUI controls will be
added for slicing along "extra" axes. By default the two-dimensional
slice containing axes 1 and 2 are shown, but that can be changed by
passing a different setting for `axes`.

If the image is grayscale, by default contrast is set by a
`scaleminmax` object whose end-points can be modified by
right-clicking on the image. If `clim == nothing`, the image's own
native contrast is used (`clamp01nan`).  You may also pass a custom
contrast function.

Finally, you may specify [`GtkReactive.ZoomRegion`](@ref) and
[`SliceData`](@ref) signals. See also [`roi`](@ref), as well as any
`annotations` that you wish to apply.
"""
function imshow(img::AbstractArray;
                axes = default_axes(img), name="ImageView", scalei=identity, aspect=:auto,
                kwargs...)
    imgmapped = kwhandler(_mappedarray(scalei, img), axes; kwargs...)
    zr, sd = roi(imgmapped, axes)
    v = slice2d(imgmapped, value(zr), sd)
    imshow(imgmapped, default_clim(v), zr, sd; name=name, aspect=aspect)
end

imshow(img::AbstractVector; kwargs...) = imshow(reshape(img, :, 1); kwargs...)

function imshow(c::GtkReactive.Canvas, img::AbstractMatrix, anns=Signal(Dict{UInt,Any}());
                kwargs...)
    f = parent(widget(c))
    imshow(f, c, img, default_clim(img), roi(img, default_axes(img))..., anns; kwargs...)
end

function imshow(img::AbstractArray, clim;
                axes = default_axes(img), name="ImageView", aspect=:auto)
    imshow(img, clim, roi(img, axes)...; name=name, aspect=aspect)
end

function imshow(img::AbstractArray, clim,
                zr::Signal{ZoomRegion{T}}, sd::SliceData,
                anns=Signal(Dict{UInt,Any}());
                name="ImageView", aspect=:auto) where T
    v = slice2d(img, value(zr), sd)
    ps = map(abs, pixelspacing(v))
    csz = default_canvas_size(fullsize(value(zr)), ps[2]/ps[1])
    guidict = imshow_gui(csz, sd; name=name, aspect=aspect)
    guidict["hoverinfo"] = map(guidict["canvas"].mouse.motion; name="hoverinfo") do btn
        hoverinfo(guidict["status"], btn, img, sd)
    end

    roidict = imshow(guidict["frame"], guidict["canvas"], img,
                     wrap_signal(clim), zr, sd, anns)

    showall(guidict["window"])
    Dict("gui"=>guidict, "clim"=>clim, "roi"=>roidict, "annotations"=>anns)
end

function imshow(frame::Gtk.GtkFrame, canvas::GtkReactive.Canvas,
                img::AbstractArray, clim::Union{Void,Signal{<:CLim}},
                zr::Signal{ZoomRegion{T}}, sd::SliceData,
                anns::Signal{Dict{UInt,Any}}=Signal(Dict{UInt,Any}())) where T
    imgsig = map(zr, sd.signals...; name="imgsig") do r, s...
        while length(s) < 2
            s = (s..., 1)
        end
        for (h, ann) in value(anns)
            setvalid!(ann, s...)
        end
        slice2d(img, r, sd)
    end
    set_aspect!(frame, value(imgsig))
    imgc = prep_contrast(canvas, imgsig, clim)
    GtkReactive.gc_preserve(frame, imgc)

    roidict = imshow(frame, canvas, imgc, zr, anns)
    roidict["slicedata"] = sd
    roidict
end

# For things that are not AbstractArrays, we don't offer the clim
# option.  We also don't display hoverinfo, as there is no guarantee
# that one can quickly compute intensities at a point.
function imshow(img;
                axes = default_axes(img), name="ImageView", aspect=:auto)
    zr, sd = roi(img, axes)
    imshow(img, zr, sd; name=name, aspect=aspect)
end

function imshow(img,
                zr::Signal{ZoomRegion{T}}, sd::SliceData,
                anns=Signal(Dict{UInt,Any}());
                name="ImageView", aspect=:auto) where T
    v = slice2d(img, value(zr), sd)
    ps = map(abs, pixelspacing(v))
    csz = default_canvas_size(fullsize(value(zr)), ps[2]/ps[1])
    guidict = imshow_gui(csz, sd; name=name, aspect=aspect)

    roidict = imshow(guidict["frame"], guidict["canvas"], img, zr, sd, anns)

    showall(guidict["window"])
    Dict("gui"=>guidict, "roi"=>roidict)
end

function imshow(frame::Gtk.GtkFrame, canvas::GtkReactive.Canvas,
                img, zr::Signal{ZoomRegion{T}}, sd::SliceData,
                anns::Signal{Dict{UInt,Any}}=Signal(Dict{UInt,Any}())) where T
    imgsig = map(zr, sd.signals...; name="imgsig") do r, s...
        slice2d(img, r, sd)
    end
    set_aspect!(frame, value(imgsig))
    GtkReactive.gc_preserve(frame, imgsig)

    roidict = imshow(frame, canvas, imgsig, zr, anns)
    roidict["slicedata"] = sd
    roidict
end

"""
    imshow_gui(canvassize, slicedata, gridsize=(1,1); name="ImageView", aspect=:auto) -> guidict

Create an image-viewer GUI. By default creates a single canvas, but
with custom `gridsize` you can create a grid of canvases. `canvassize
= (szx, szy)` describes the desired size of the (or each)
canvas. `slicedata` is an object created by [`roi`](@ref) that encodes
the necessary information for creating player widgets for viewing
multidimensional images.
"""
function imshow_gui(canvassize::Tuple{Int,Int},
                    sd::SliceData=SliceData{false}(),
                    gridsize::Tuple{Int,Int} = (1,1);
                    name = "ImageView", aspect=:auto)
    winsize = canvas_size(screen_size(), map(*, canvassize, gridsize))
    win = Window(name, winsize...)
    window_wrefs[win] = nothing
    signal_connect(win, :destroy) do w
        delete!(window_wrefs, win)
    end
    vbox = Box(:v)
    push!(win, vbox)
    if gridsize == (1,1)
        frames, canvases = frame_canvas(aspect)
        g = frames
    else
        g, frames, canvases = canvasgrid(gridsize, aspect)
    end
    push!(vbox, g)
    status = Label("")
    setproperty!(status, :halign, Gtk.GConstants.GtkAlign.START)
    push!(vbox, status)

    guidict = Dict("window"=>win, "vbox"=>vbox, "frame"=>frames, "status"=>status,
                   "canvas"=>canvases)

    # Add the player controls
    if !isempty(sd)
        players = [player(sd.signals[i], axisvalues(sd.axs[i])[1]; id=i) for i = 1:length(sd)]
        guidict["players"] = players
        hbox = Box(:h)
        for p in players
            push!(hbox, frame(p))
        end
        push!(guidict["vbox"], hbox)
    end

    guidict
end

fullsize(zr::ZoomRegion) =
    map(i->length(UnitRange{Int}(i)), (zr.fullview.y, zr.fullview.x))

"""
    grid, frames, canvases = canvasgrid((ny, nx))

Create a grid of `ny`-by-`nx` canvases for drawing. `grid` is a
GtkGrid layout, `frames` is an `ny`-by-`nx` array of
GtkAspectRatioFrames that contain each canvas, and `canvases` is an
`ny`-by-`nx` array of canvases.
"""
function canvasgrid(gridsize::Tuple{Int,Int}, aspect=:auto)
    g = Grid()
    frames = Matrix{Any}(gridsize)
    canvases = Matrix{Any}(gridsize)
    for j = 1:gridsize[2], i = 1:gridsize[1]
        f, c = frame_canvas(aspect)
        g[j,i] = f
        frames[i,j] = f
        canvases[i,j] = c
    end
    return g, frames, canvases
end

function frame_canvas(aspect)
    f = aspect==:none ? Frame() : AspectFrame("", 0.5, 0.5, 1)
    setproperty!(f, :expand, true)
    setproperty!(f, :shadow_type, Gtk.GConstants.GtkShadowType.NONE)
    c = canvas(UserUnit)
    push!(f, widget(c))
    f, c
end

"""
    imshow(canvas, imgsig::Signal, zr::Signal{ZoomRegion}) -> guidict
    imshow(frame::Frame, canvas, imgsig::Signal, zr::Signal{ZoomRegion}) -> guidict

Display `imgsig` (a `Signal` of an image) in `canvas`, setting up
panning and zooming. Optionally include a `frame` for preserving
aspect ratio. `imgsig` must be two-dimensional (but can be a
Signal-view of a higher-dimensional object).
"""
function imshow(canvas::GtkReactive.Canvas{UserUnit},
                imgsig::Signal,
                zr::Signal{ZoomRegion{T}},
                anns::Signal{Dict{UInt,Any}}=Signal(Dict{UInt,Any}())) where T<:RInteger
    zoomrb = init_zoom_rubberband(canvas, zr)
    zooms = init_zoom_scroll(canvas, zr)
    pans = init_pan_scroll(canvas, zr)
    pand = init_pan_drag(canvas, zr)
    redraw = imshow!(canvas, imgsig, zr, anns)
    dct = Dict("image roi"=>imgsig, "zoomregion"=>zr, "zoom_rubberband"=>zoomrb,
               "zoom_scroll"=>zooms, "pan_scroll"=>pans, "pan_drag"=>pand,
               "redraw"=>redraw)
    GtkReactive.gc_preserve(widget(canvas), dct)
    dct
end

function imshow(frame::Frame,
                canvas::GtkReactive.Canvas{UserUnit},
                imgsig::Signal,
                zr::Signal{ZoomRegion{T}},
                anns::Signal{Dict{UInt,Any}}=Signal(Dict{UInt,Any}())) where T<:RInteger
    zoomrb = init_zoom_rubberband(canvas, zr)
    zooms = init_zoom_scroll(canvas, zr)
    pans = init_pan_scroll(canvas, zr)
    pand = init_pan_drag(canvas, zr)
    redraw = imshow!(frame, canvas, imgsig, zr, anns)
    dct = Dict("image roi"=>imgsig, "zoomregion"=>zr, "zoom_rubberband"=>zoomrb,
               "zoom_scroll"=>zooms, "pan_scroll"=>pans, "pan_drag"=>pand,
               "redraw"=>redraw)
    GtkReactive.gc_preserve(widget(canvas), dct)
    dct
end

"""
    imshowlabeled(img, label)

Display `img`, but showing the pixel's `label` rather than the color
value in the status bar.
"""
function imshowlabeled(img::AbstractArray, label::AbstractArray; proplist...)
    indices(img) == indices(label) || throw(DimensionMismatch("indices $(indices(label)) of label array disagree with indices $(indices(img)) of the image"))
    guidict = imshow(img; proplist...)
    gui = guidict["gui"]
    sd = guidict["roi"]["slicedata"]
    close(gui["hoverinfo"])
    gui["hoverinfo"] = map(gui["canvas"].mouse.motion; name="hoverinfo") do btn
        hoverinfo(gui["status"], btn, label, sd)
    end
    guidict
end

function hoverinfo(lbl, btn, img, sd::SliceData{transpose}) where transpose
    io = IOBuffer()
    y, x = round(Int, btn.position.y.val), round(Int, btn.position.x.val)
    indices = sliceinds(img, transpose ? (x, y) : (y, x), makeslices(sd)...)
    if checkbounds(Bool, img, indices...)
        print(io, '[', y, ',', x, "] ")
        showcompact(io, img[indices...])
        setproperty!(lbl, :label, String(take!(io)))
    else
        setproperty!(lbl, :label, "")
    end
end

default_clim(img) = nothing
default_clim(img::AbstractArray{C}) where {C<:GrayLike} = _default_clim(img, eltype(C))
_default_clim(img, ::Type{Bool}) = nothing
_default_clim(img, ::Type{T}) where {T} = _deflt_clim(img)
function _deflt_clim(img::AbstractMatrix)
    minval = nanz(minfinite(img))
    maxval = nanz(maxfinite(img))
    if minval == maxval
        minval = zero(typeof(minval))
        maxval = one(typeof(maxval))
    end
    Signal(CLim(saferound(gray(minval)), saferound(gray(maxval))); name="CLim")
end

saferound(x::Integer) = convert(RInteger, x)
saferound(x) = x

default_axes(::AbstractVector) = (1,)
default_axes(img) = (1, 2)
default_axes(img::AxisArray) = axisnames(img)[[1,2]]

#default_view(img) = view(img, :, :, ntuple(d->1, ndims(img)-2)...)
#default_view(img::Signal) = default_view(value(img))

# default_slices(img) = ntuple(d->PlayerInfo(Signal(1), indices(img, d+2)), ndims(img)-2)

function prep_contrast(img::Signal, clim::Signal{CLim{T}}) where T
    # Set up the signals to calculate the histogram of intensity
    enabled = Signal(false; name="contrast_enabled") # skip hist calculation if the contrast gui isn't open
    histsig = map(filterwhen(enabled, value(img), img); name="histsig") do image
        cl = value(clim)
        smin = float(nanz(min(minfinite(image), cl.min)))
        smax = float(nanz(max(maxfinite(image), cl.max)))
        if smax == smin
            smax = smin+1
        end
        rng = linspace(smin, smax, 300)
        fit(Histogram, mappedarray(nanz, vec(channelview(image))), rng; closed=:right)
    end
    # Return a signal corresponding to the scaled image
    imgc = map(img, clim; name="clim-mapped image") do image, cl
        cmin, cmax = cl.min, cl.max
        if !(cmin < cmax)
            cmax = cmin+1
        end
        smm = scaleminmax(Gray{N0f8}, cmin, cmax)
        mappedarray(smm, image)
    end
    enabled, histsig, imgc
end

function prep_contrast(canvas, img::Signal, clim::Signal{CLim{T}}) where T
    enabled, histsig, imgsig = prep_contrast(img, clim)
    # Set up the right-click to open the contrast gui
    push!(canvas.preserved, create_contrast_popup(canvas, enabled, histsig, clim))
    imgsig
end

prep_contrast(canvas, img::Signal, f) =
    map(image->mappedarray(f, image), img; name="f-mapped image")
prep_contrast(canvas, img::Signal{A}, ::Void) where {A<:AbstractArray} =
    prep_contrast(canvas, img, clamp01nan)
prep_contrast(canvas, img::Signal, ::Void) = img

nanz(x) = ifelse(isnan(x), zero(x), x)
nanz(x::FixedPoint) = x
nanz(x::Integer) = x

function create_contrast_popup(canvas, enabled, hist, clim)
    popupmenu = Menu()
    contrast = MenuItem("Contrast...")
    push!(popupmenu, contrast)
    showall(popupmenu)
    push!(canvas.preserved, map(canvas.mouse.buttonpress; name="open contrast GUI") do btn
        if btn.button == 3 && btn.clicktype == BUTTON_PRESS
            popup(popupmenu, btn.gtkevent)
        end
    end)
    signal_connect(contrast, :activate) do widget
        push!(enabled, true)
        contrast_gui(enabled, hist, clim)
    end
end

function map_image_roi(img, zr::Signal{ZoomRegion{T}}, slices...) where T
    map(zr, slices...; name="map_image_roi") do r, s...
        cv = r.currentview
        view(img, UnitRange{Int}(cv.y), UnitRange{Int}(cv.x), s...)
    end
end
map_image_roi(img::Signal, zr::Signal{ZoomRegion{T}}, slices...) where {T} = img

function set_aspect!(frame::AspectFrame, image)
    ps = map(abs, pixelspacing(image))
    sz = map(length, indices(image))
    r = sz[2]*ps[2]/(sz[1]*ps[1])
    setproperty!(frame, :ratio, r)
    nothing
end
set_aspect!(frame, image) = nothing

"""
    default_canvas_size(imagesize, pixelaspectratio=1) -> (xsz, ysz)

Compute the canvas size for an image of size `imagesize` with the
defined `pixelaspectratio`. Note that `imagesize` is supplied in
coordinate order, i.e., (y, x) order, whereas the returned canvas size
is in Gtk order, i.e., (x, y) order.
"""
default_canvas_size(imgsz::Tuple{Integer,Integer}, pixelaspectratio::Number=1) =
    pixelaspectratio >= 1 ? (round(Int, pixelaspectratio*imgsz[2]), Int(imgsz[1])) :
        (Int(imgsz[2]), round(Int, imgsz[1]/pixelaspectratio))

"""
    canvas_size(win, requested_size) -> (xsz, ysz)
    canvas_size(screensize, requested_size) -> (xsz, ysz)

Limit the requested canvas size by the screen size. Both the output
and `screensize` are supplied in Gtk order (x, y).

When supplying a GtkWindow `win`, the canvas size is limited to 60% of
the total screen size.
"""
function canvas_size(win::Gtk.GtkWindowLeaf, requestedsize_xy; minsize=100)
    ssz = screen_size(win)
    canvas_size(map(x->0.6*x, ssz), requestedsize_xy; minsize=minsize)
end

function canvas_size(screensize_xy, requestedsize_xy; minsize=100)
    f = minimum(map(/, screensize_xy, requestedsize_xy))
    if f > 1
        fmn = maximum(map(/, (minsize,minsize), requestedsize_xy))
        f = max(1, min(f, fmn))
    end
    (round(Int, f*requestedsize_xy[1]), round(Int, f*requestedsize_xy[2]))
end

function kwhandler(img, axes; flipx=false, flipy=false, kwargs...)
    if flipx || flipy
        inds = Range[indices(img)...]
        setrange!(inds, _axisdim(img, axes[1]), flipy)
        setrange!(inds, _axisdim(img, axes[2]), flipx)
        img = view(img, inds...)
    end
    for (k, v) in kwargs
        if k == :xy
            error("The `xy` keyword has been renamed `axes`, and it takes dimensions or Symbols (if using an AxisArray)")
        end
    end
    pixelspacing_dep(img, kwargs)
end
function setrange!(inds, ax::Integer, flip)
    ind = inds[ax]
    inds[ax] = flip ? (last(ind):-1:first(ind)) : ind
    inds
end
_axisdim(img, ax::Integer) = ax
_axisdim(img, ax::Axis) = axisdim(img, ax)
_axisdim(img, ax) = axisdim(img, Axis{ax})


isgray(img::AbstractArray{T}) where {T<:Real} = true
isgray(img::AbstractArray{T}) where {T<:AbstractGray} = true
isgray(img) = false

_mappedarray(f, img) = mappedarray(f, img)
_mappedarray(f, img::AxisArray) = AxisArray(mappedarray(f, img.data), axes(img))
_mappedarray(f, img::ImageMeta) = shareproperties(img, _mappedarray(f, data(img)))

wrap_signal(x) = Signal(x)
wrap_signal(x::Signal) = x
wrap_signal(::Void) = nothing

include("link.jl")
include("contrast_gui.jl")
include("annotations.jl")
include("deprecated.jl")

end # module
