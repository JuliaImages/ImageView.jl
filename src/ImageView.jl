module ImageView

using ImageCore, ImageBase, StatsBase
using ImageCore.MappedArrays
using RoundingIntegers
using Gtk.ShortNames, GtkReactive, Graphics, Cairo
using Gtk.GConstants.GtkAlign: GTK_ALIGN_START, GTK_ALIGN_END, GTK_ALIGN_FILL
using AxisArrays: AxisArrays, Axis, AxisArray, axisnames, axisvalues
using ImageMetadata

import ImageCore: scaleminmax

export AnnotationText, AnnotationPoint, AnnotationPoints,
       AnnotationLine, AnnotationLines, AnnotationBox
export CLim, annotate!, annotations, canvasgrid, imshow, imshow!, imshow_gui, imlink,
       roi, scalebar, slice2d

const AbstractGray{T} = Color{T,1}
const GrayLike = Union{AbstractGray,Number}
const FixedColorant{T<:FixedPoint} = Colorant{T}
const Annotations = Signal{Dict{UInt,Any}}

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

const window_wrefs = WeakKeyDict{Gtk.GtkWindowLeaf,Nothing}()

"""
    imshow()

Choose an image to display via a file dialog.
"""
imshow() = imshow(load(open_dialog("Pick an image to display")))

"""
    imshow!(canvas, img) -> drawsignal
    imshow!(canvas, img::Signal, zr::Signal{ZoomRegion}) -> drawsignal
    imshow!(frame::Frame, canvas, img::Signal, zr::Signal{ZoomRegion}) -> drawsignal
    imshow!(..., anns=annotations())

Display the image `img`, in the specified `canvas`. Use the version
with `zr` if you have already turned on rubber-banding or other
pan/zoom interactivity for `canvas`. Returns the Reactive `drawsignal`
used for updating the canvas.

If you supply `frame`, then the pixel aspect ratio will be set to that
of `pixelspacing(img)`.

With any of these forms, you may optionally supply `annotations`.

This only creates the `draw` method for `canvas`; mouse- or key-based
interactivity can be set up via [`imshow`](@ref) or, at a lower level,
using GtkReactive's tools:

- `init_zoom_rubberband`
- `init_zoom_scroll`
- `init_pan_scroll`
- `init_pan_drag`

# Example

```julia
using ImageView, GtkReactive, Gtk.ShortNames, TestImages
# Create a window with a canvas in it
win = Window()
c = canvas(UserUnit)
push!(win, c)
Gtk.showall(win)
# Load images
mri = testimage("mri")
# Display the image
imshow!(c, mri[:,:,1])
# Update with a different image
imshow!(c, mri[:,:,8])
"""
function imshow!(canvas::GtkReactive.Canvas{UserUnit},
                 imgsig::Signal,
                 zr::Signal{ZoomRegion{T}},
                 annotations::Annotations=annotations()) where T<:RInteger
    draw(canvas, imgsig, annotations) do cnvs, image, anns
        copy!(cnvs, image)
        set_coordinates(cnvs, value(zr))
        draw_annotations(cnvs, anns)
    end
end

function imshow!(frame::Frame,
                 canvas::GtkReactive.Canvas{UserUnit},
                 imgsig::Signal,
                 zr::Signal{ZoomRegion{T}},
                 annotations::Annotations=annotations()) where T<:RInteger
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
                 annotations::Annotations=annotations())
    draw(canvas, imgsig, annotations) do cnvs, image, anns
        copy!(cnvs, image)
        set_coordinates(cnvs, axes(image))
        draw_annotations(cnvs, anns)
    end
end

# Simple non-interactive image display
function imshow!(canvas::GtkReactive.Canvas,
                 img::AbstractMatrix,
                 annotations::Annotations=annotations())
    draw(canvas, annotations) do cnvs, anns
        copy!(cnvs, img)
        set_coordinates(cnvs, axes(img))
        draw_annotations(cnvs, anns)
    end
    nothing
end

"""
    imshow(img; axes=(1,2), name="ImageView") -> guidict
    imshow(img, clim; kwargs...) -> guidict
    imshow(img, clim, zoomregion, slicedata, annotations; kwargs...) -> guidict

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

Other supported keyword arguments include:
- `scalei=identity` as an intensity-scaling function prior to display
- `aspect=:auto` to control the aspect ratio of the image
- `flipx=false`, `flipy=false` to flip axes
- `canvassize=nothing` to control the size of the window (`nothing` chooses based on image size)
"""
function imshow(img::AbstractArray;
                axes=default_axes(img), name="ImageView", scalei=identity, aspect=:auto,
                kwargs...)
    @nospecialize
    imgmapped, kwargs = kwhandler(_mappedarray(scalei, img), axes; kwargs...)
    zr, sd = roi(imgmapped, axes)
    v = slice2d(imgmapped, value(zr), sd)
    imshow(imgmapped, default_clim(v), zr, sd; name=name, aspect=aspect, kwargs...)
end

imshow(img::AbstractVector; kwargs...) = (@nospecialize; imshow(reshape(img, :, 1); kwargs...))

function imshow(c::GtkReactive.Canvas, img::AbstractMatrix, anns=annotations(); kwargs...)
    @nospecialize
    f = parent(widget(c))
    imshow(f, c, img, default_clim(img), roi(img, default_axes(img))..., anns; kwargs...)
end

function imshow(img::AbstractArray, clim;
                axes = default_axes(img), name="ImageView", aspect=:auto, kwargs...)
    @nospecialize
    img, kwargs = kwhandler(img, axes; kwargs...)
    imshow(img, clim, roi(img, axes)...; name=name, aspect=aspect, kwargs...)
end

function imshow(img::AbstractArray, clim,
                zr::Signal{ZoomRegion{T}}, sd::SliceData,
                anns=annotations();
                name="ImageView", aspect=:auto, canvassize::Union{Nothing,Tuple{Int,Int}}=nothing) where T
    @nospecialize
    v = slice2d(img, value(zr), sd)
    ps = map(abs, pixelspacing(v))
    if canvassize === nothing
        canvassize = default_canvas_size(fullsize(value(zr)), ps[2]/ps[1])
    end
    guidict = imshow_gui(canvassize, sd; name=name, aspect=aspect)
    guidict["hoverinfo"] = map(guidict["canvas"].mouse.motion; name="hoverinfo") do btn
        hoverinfo(guidict["status"], btn, img, sd)
    end

    roidict = imshow(guidict["frame"], guidict["canvas"], img,
                     wrap_signal(clim), zr, sd, anns)

    win = guidict["window"]
    Gtk.showall(win)
    dct = Dict("gui"=>guidict, "clim"=>clim, "roi"=>roidict, "annotations"=>anns)
    GtkReactive.gc_preserve(win, dct)
    return dct
end

function imshow(frame::Gtk.GtkFrame, canvas::GtkReactive.Canvas,
                img::AbstractArray, clim::Union{Nothing,Signal{<:CLim}},
                zr::Signal{ZoomRegion{T}}, sd::SliceData,
                anns::Annotations=annotations()) where T
    @nospecialize
    imgsig = map(zr, sd.signals...; name="imgsig") do r, s...
        @nospecialize
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
    @nospecialize
    zr, sd = roi(img, axes)
    imshow(img, zr, sd; name=name, aspect=aspect)
end

function imshow(img,
                zr::Signal{ZoomRegion{T}}, sd::SliceData,
                anns=annotations();
                name="ImageView", aspect=:auto) where T
    @nospecialize
    v = slice2d(img, value(zr), sd)
    ps = map(abs, pixelspacing(v))
    csz = default_canvas_size(fullsize(value(zr)), ps[2]/ps[1])
    guidict = imshow_gui(csz, sd; name=name, aspect=aspect)

    roidict = imshow(guidict["frame"], guidict["canvas"], img, zr, sd, anns)

    win = guidict["window"]
    Gtk.showall(win)
    dct = Dict("gui"=>guidict, "roi"=>roidict)
    GtkReactive.gc_preserve(win, dct)
    return dct
end

function imshow(frame::Gtk.GtkFrame, canvas::GtkReactive.Canvas,
                img, zr::Signal{ZoomRegion{T}}, sd::SliceData,
                anns::Annotations=annotations()) where T
    @nospecialize
    imgsig = map(zr, sd.signals...; name="imgsig") do r, s...
        @nospecialize
        slice2d(img, r, sd)
    end
    set_aspect!(frame, value(imgsig))
    GtkReactive.gc_preserve(frame, imgsig)

    roidict = imshow(frame, canvas, imgsig, zr, anns)
    roidict["slicedata"] = sd
    GtkReactive.gc_preserve(frame, roidict)
    roidict
end

"""
    guidict = imshow_gui(canvassize, gridsize=(1,1); name="ImageView", aspect=:auto, slicedata=SliceData{false}())

Create an image-viewer GUI. By default creates a single canvas, but
with custom `gridsize = (nx, ny)` you can create a grid of canvases.
`canvassize = (szx, szy)` describes the desired size of the (or each) canvas.

Optionally provide a `name` for the window.
`aspect` should be `:auto` or `:none`, with the former preserving the pixel aspect ratio
as the window is resized.
`slicedata` is an object created by [`roi`](@ref) that encodes
the necessary information for creating player widgets for viewing
multidimensional images.
"""
function imshow_gui(canvassize::Tuple{Int,Int},
                    gridsize::Tuple{Int,Int} = (1,1);
                    name = "ImageView", aspect=:auto,
                    slicedata::SliceData=SliceData{false}())
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
    set_gtk_property!(status, :halign, Gtk.GConstants.GtkAlign.START)
    push!(vbox, status)

    guidict = Dict("window"=>win, "vbox"=>vbox, "frame"=>frames, "status"=>status,
                   "canvas"=>canvases)

    # Add the player controls
    if !isempty(slicedata)
        players = [player(slicedata.signals[i], axisvalues(slicedata.axs[i])[1]; id=i) for i = 1:length(slicedata)]
        guidict["players"] = players
        hbox = Box(:h)
        for p in players
            push!(hbox, frame(p))
        end
        push!(guidict["vbox"], hbox)
    end

    guidict
end

imshow_gui(canvassize::Tuple{Int,Int}, slicedata::SliceData, args...; kwargs...) =
    imshow_gui(canvassize, args...; slicedata=slicedata, kwargs...)

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
    frames = Matrix{Any}(undef, gridsize)
    canvases = Matrix{Any}(undef, gridsize)
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
    set_gtk_property!(f, :expand, true)
    set_gtk_property!(f, :shadow_type, Gtk.GConstants.GtkShadowType.NONE)
    c = canvas(UserUnit)
    push!(f, widget(c))
    f, c
end

"""
    imshow(canvas, imgsig::Signal) -> guidict
    imshow(canvas, imgsig::Signal, zr::Signal{ZoomRegion}) -> guidict
    imshow(frame::Frame, canvas, imgsig::Signal, zr::Signal{ZoomRegion}) -> guidict

Display `imgsig` (a `Signal` of an image) in `canvas`, setting up
panning and zooming. Optionally include a `frame` for preserving
aspect ratio. `imgsig` must be two-dimensional (but can be a
Signal-view of a higher-dimensional object).

# Example

```julia
using ImageView, TestImages, Gtk
mri = testimage("mri");
# Create a canvas `c`. There are other approaches, like stealing one from a previous call
# to `imshow`, or using GtkReactive directly.
guidict = imshow_gui((300, 300))
c = guidict["canvas"];
# To see anything you have to call `showall` on the window (once)
Gtk.showall(guidict["window"])
# Create the image Signal
imgsig = Signal(mri[:,:,1]);
# Show it
imshow(c, imgsig)
# Now anytime you want to update, just push! a new image
push!(imgsig, mri[:,:,8])
```
"""
function imshow(canvas::GtkReactive.Canvas{UserUnit},
                imgsig::Signal,
                zr::Signal{ZoomRegion{T}}=Signal(ZoomRegion(value(imgsig))),
                anns::Annotations=annotations()) where T<:RInteger
    @nospecialize
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
                anns::Annotations=annotations()) where T<:RInteger
    @nospecialize
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
    @nospecialize
    axes(img) == axes(label) || throw(DimensionMismatch("axes $(axes(label)) of label array disagree with axes $(axes(img)) of the image"))
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
    axes = sliceinds(img, transpose ? (x, y) : (y, x), makeslices(sd)...)
    if checkbounds(Bool, img, axes...)
        print(io, '[', y, ',', x, "] ")
        show(IOContext(io, :compact=>true), img[axes...])
        set_gtk_property!(lbl, :label, String(take!(io)))
    else
        set_gtk_property!(lbl, :label, "")
    end
end

function valuespan(img::AbstractMatrix)
    minval = minimum_finite(img)
    maxval = maximum_finite(img)
    if minval > maxval
        minval = zero(typeof(minval))
        maxval = oneunit(typeof(maxval))
    elseif minval == maxval
        maxval = minval+1
    end
    return minval, maxval
end

default_clim(img) = nothing
default_clim(img::AbstractArray{C}) where {C<:GrayLike} = _default_clim(img, eltype(C))
default_clim(img::AbstractArray{C}) where {C<:AbstractRGB} = _default_clim(img, eltype(C))
_default_clim(img, ::Type{Bool}) = nothing
_default_clim(img, ::Type{T}) where {T} = _deflt_clim(img)
function _deflt_clim(img::AbstractMatrix)
    minval, maxval = valuespan(img)
    Signal(CLim(saferound(gray(minval)), saferound(gray(maxval))); name="CLim")
end

function _deflt_clim(img::AbstractMatrix{T}) where {T<:AbstractRGB}
    minval = RGB(0.0,0.0,0.0)
    maxval = RGB(1.0,1.0,1.0)
    Signal(CLim(minval, maxval); name="CLim")
end

saferound(x::Integer) = convert(RInteger, x)
saferound(x) = x

default_axes(::AbstractVector) = (1,)
default_axes(img) = (1, 2)
default_axes(img::AxisArray) = axisnames(img)[[1,2]]

#default_view(img) = view(img, :, :, ntuple(d->1, ndims(img)-2)...)
#default_view(img::Signal) = default_view(value(img))

# default_slices(img) = ntuple(d->PlayerInfo(Signal(1), axes(img, d+2)), ndims(img)-2)

function histsignals(enabled::Signal, defaultimg, img::Signal, clim::Signal{CLim{T}}) where {T<:GrayLike}
    return [map(filterwhen(enabled, defaultimg, img), enabled; name="histsig") do image, _  # `enabled` fixes issue #168
        cl = value(clim)
        smin, smax = valuespan(image)
        smin = float(min(smin, cl.min))
        smax = float(max(smax, cl.max))
        if smax == smin
            smax = smin+1
        end
        rng = range(smin, stop=smax, length=300)
        fit(Histogram, mappedarray(nanz, vec(channelview(image))), rng; closed=:right)
    end]
end

channel_clim(f, clim::CLim{T}) where {T<:AbstractRGB} = CLim(f(clim.min), f(clim.max))
channel_clims(clim::CLim{T}) where {T<:AbstractRGB} = map(f->channel_clim(f, clim), (red, green, blue))

function mapped_channel_clims(clim::Signal{CLim{T}}) where {T<:AbstractRGB}
    inits = channel_clims(value(clim))
    rsig = map(x->channel_clim(red, x), clim; init=inits[1])
    gsig = map(x->channel_clim(green, x), clim; init=inits[1])
    bsig = map(x->channel_clim(blue, x), clim; init=inits[1])
    return [rsig;gsig;bsig]
end

function histsignals(enabled::Signal, defaultimg, img::Signal, clim::Signal{CLim{T}}) where {T<:AbstractRGB}
    rv = map(x->mappedarray(red, x), filterwhen(enabled, defaultimg, img); name="redview")
    gv = map(x->mappedarray(green,x), filterwhen(enabled, defaultimg, img); name="greenview")
    bv = map(x->mappedarray(blue, x), filterwhen(enabled, defaultimg, img); name="blueview")
    cls = mapped_channel_clims(clim) #note currently this gets called twice, also in contrast gui creation (a bit inefficient/awkward)
    histsigs = []
    push!(histsigs, histsignals(enabled, mappedarray(red, defaultimg), rv, cls[1])[1])
    push!(histsigs, histsignals(enabled, mappedarray(green, defaultimg), gv, cls[2])[1])
    push!(histsigs, histsignals(enabled, mappedarray(blue, defaultimg), bv, cls[3])[1])
    return histsigs
end

function scaleminmax(::Type{Tout}, cmin::AbstractRGB{T}, cmax::AbstractRGB{T}) where {T,Tout}
    r = scaleminmax(T, red(cmin), red(cmax))
    g = scaleminmax(T, green(cmin), green(cmax))
    b = scaleminmax(T, blue(cmin), blue(cmax))
    return x->Tout(nanz(r(red(x))), nanz(g(green(x))), nanz(b(blue(x))))
end

function safeminmax(cmin::T, cmax::T) where {T<:GrayLike}
    if !(cmin < cmax)
        cmax = cmin+1
    end
    return cmin, cmax
end

function safeminmax(cmin::T, cmax::T) where {T<:AbstractRGB}
    rmin, rmax = safeminmax(red(cmin), red(cmax))
    gmin, gmax = safeminmax(green(cmin), green(cmax))
    bmin, bmax = safeminmax(blue(cmin), blue(cmax))
    return T(rmin, gmin, bmin), T(rmax, gmax, bmax)
end

function prep_contrast(img::Signal, clim::Signal{CLim{T}}) where {T}
    # Set up the signals to calculate the histogram of intensity
    enabled = Signal(false; name="contrast_enabled") # skip hist calculation if the contrast gui isn't open
    histsigs = histsignals(enabled, value(img), img, clim)
    # Return a signal corresponding to the scaled image
    imgc = map(img, clim; name="clim-mapped image") do image, cl
        cmin, cmax = safeminmax(cl.min, cl.max)
        smm = scaleminmax(outtype(T), cmin, cmax)
        mappedarray(smm, image)
    end
    enabled, histsigs, imgc
end

outtype(::Type{T}) where T<:GrayLike         = Gray{N0f8}
outtype(::Type{C}) where C<:Color            = RGB{N0f8}
outtype(::Type{C}) where C<:TransparentColor = RGBA{N0f8}

function prep_contrast(canvas, img::Signal, clim::Signal{CLim{T}}) where T
    enabled, histsigs, imgsig = prep_contrast(img, clim)
    # Set up the right-click to open the contrast gui
    push!(canvas.preserved, create_contrast_popup(canvas, enabled, histsigs, clim))
    imgsig
end

prep_contrast(canvas, img::Signal, f) =
    map(image->mappedarray(f, image), img; name="f-mapped image")
prep_contrast(canvas, img::Signal{A}, ::Nothing) where {A<:AbstractArray} =
    prep_contrast(canvas, img, clamp01nan)
prep_contrast(canvas, img::Signal, ::Nothing) = img

nanz(x) = ifelse(isnan(x), zero(x), x)
nanz(x::FixedPoint) = x
nanz(x::Integer) = x

function create_contrast_popup(canvas, enabled, hists, clim)
    popupmenu = Menu()
    contrast = MenuItem("Contrast...")
    push!(popupmenu, contrast)
    Gtk.showall(popupmenu)
    push!(canvas.preserved, map(canvas.mouse.buttonpress; name="open contrast GUI") do btn
        if btn.button == 3 && btn.clicktype == BUTTON_PRESS
            popup(popupmenu, btn.gtkevent)
        end
    end)
    signal_connect(contrast, :activate) do widget
        push!(enabled, true)
        contrast_gui(enabled, hists, clim)
    end
end

function map_image_roi(@nospecialize(img), zr::Signal{ZoomRegion{T}}, slices...) where T
    map(zr, slices...; name="map_image_roi") do r, s...
        cv = r.currentview
        view(img, UnitRange{Int}(cv.y), UnitRange{Int}(cv.x), s...)
    end
end
map_image_roi(img::Signal, zr::Signal{ZoomRegion{T}}, slices...) where {T} = img

function set_aspect!(frame::AspectFrame, image)
    ps = map(abs, pixelspacing(image))
    sz = map(length, axes(image))
    r = sz[2]*ps[2]/(sz[1]*ps[1])
    set_gtk_property!(frame, :ratio, r)
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

function kwhandler(@nospecialize(img), axs; flipx=false, flipy=false, kwargs...)
    if flipx || flipy
        inds = AbstractRange[axes(img)...]
        setrange!(inds, _axisdim(img, axs[1]), flipy)
        setrange!(inds, _axisdim(img, axs[2]), flipx)
        img = view(img, inds...)
    end
    img, kwargs
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
_mappedarray(f, img::AxisArray) = AxisArray(mappedarray(f, img.data), AxisArrays.axes(img))
_mappedarray(f, img::ImageMeta) = shareproperties(img, _mappedarray(f, data(img)))

wrap_signal(x) = Signal(x)
wrap_signal(x::Signal) = x
wrap_signal(::Nothing) = nothing

include("link.jl")
include("contrast_gui.jl")
include("annotations.jl")

include("precompile.jl")
_precompile_()

end # module
