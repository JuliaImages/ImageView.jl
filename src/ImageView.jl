module ImageView
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 1
end
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

using ImageCore, ImageBase, StatsBase
using ImageCore.MappedArrays
using RoundingIntegers
using Gtk4, GtkObservables, Graphics, Cairo
using Gtk4: Align_START, Align_END, Align_FILL
using GtkObservables.Observables
using AxisArrays: AxisArrays, Axis, AxisArray, axisnames, axisvalues, axisdim
using Compat # for @constprop :none

export AnnotationText, AnnotationPoint, AnnotationPoints,
       AnnotationLine, AnnotationLines, AnnotationBox
export CLim, annotate!, annotations, canvasgrid, imshow, imshow!, imshow_gui, imlink,
       roi, scalebar, setup_contrast_popup!, slice2d

const AbstractGray{T} = Color{T,1}
const GrayLike = Union{AbstractGray,Number}
const FixedColorant{T<:FixedPoint} = Colorant{T}
const Annotations = Observable{Dict{UInt,Any}}

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
    ImageViewGUI

Holds the GTK widgets that make up an `ImageView` window: the window itself,
its layout containers, frame(s), canvas(es), the status and view labels, and
(for multidimensional images) the player widgets used to scrub through slices.

In a grid layout, `frame` and `canvas` are `Matrix`es of widgets; for a
single-image window they are individual widgets.

Returned by [`imshow_gui`](@ref) and accessible as `disp.gui` on an
[`ImageDisplay`](@ref).
"""
mutable struct ImageViewGUI
    window
    vbox
    frame
    canvas
    status
    viewlabel
    players          # Vector or `nothing`
    hoverinfo        # Observer handle or `nothing`; set after construction
    zoomregion_info  # Observer handle or `nothing`; set after construction
    extras::Dict{Symbol,Any}
end
ImageViewGUI(window, vbox, frame, canvas, status, viewlabel, players=nothing) =
    ImageViewGUI(window, vbox, frame, canvas, status, viewlabel, players,
                 nothing, nothing, Dict{Symbol,Any}())

"""
    ImageROI

Holds the region-of-interest state and pan/zoom interaction signals for a
displayed image: the currently-shown image slice (`image_roi`), the
`zoomregion` observable, signals for rubberband/scroll zooming and panning,
the redraw signal, and the `slicedata` (when the source image has more than
two dimensions).

Returned by `imshow(::Canvas, ...)` and accessible as `disp.roi` on an
[`ImageDisplay`](@ref).
"""
mutable struct ImageROI
    image_roi
    zoomregion
    zoom_rubberband
    zoom_scroll
    pan_scroll
    pan_drag
    redraw
    slicedata        # `SliceData` or `nothing`
end
ImageROI(image_roi, zoomregion, zoom_rubberband, zoom_scroll, pan_scroll, pan_drag, redraw) =
    ImageROI(image_roi, zoomregion, zoom_rubberband, zoom_scroll, pan_scroll, pan_drag, redraw, nothing)

"""
    ImageDisplay

The handle returned by [`imshow`](@ref). Composes an [`ImageViewGUI`](@ref)
(accessible via `disp.gui` or by hoisted fields like `disp.window`,
`disp.canvas`), an [`ImageROI`](@ref) (via `disp.roi` or hoisted fields like
`disp.zoomregion`, `disp.image_roi`), an optional `clim`, and the
`annotations` observable.

`ImageDisplay` overloads `Base.getproperty` so any field of the nested `gui`
or `roi` can be reached directly on the top-level handle. Downstream packages
that need to dispatch on "an ImageView display" should dispatch on this type.

`Base.show` deliberately prints only a compact summary; it never prints the
underlying image array.
"""
struct ImageDisplay
    gui::ImageViewGUI
    roi::ImageROI
    clim             # `Observable{<:CLim}` or `nothing`
    annotations      # `Annotations` (= `Observable{Dict{UInt,Any}}`)
end

function Base.getproperty(d::ImageDisplay, name::Symbol)
    name === :gui         && return getfield(d, :gui)
    name === :roi         && return getfield(d, :roi)
    name === :clim        && return getfield(d, :clim)
    name === :annotations && return getfield(d, :annotations)
    g = getfield(d, :gui)
    hasfield(ImageViewGUI, name) && return getfield(g, name)
    r = getfield(d, :roi)
    hasfield(ImageROI, name) && return getfield(r, name)
    throw(ArgumentError("ImageDisplay has no property `$name`. Available: $(propertynames(d))"))
end

Base.propertynames(::ImageDisplay) =
    (:gui, :roi, :clim, :annotations,
     fieldnames(ImageViewGUI)..., fieldnames(ImageROI)...)

function Base.show(io::IO, d::ImageDisplay)
    img = getfield(d, :roi).image_roi
    print(io, "ImageDisplay(", eltype(img[]), ", ", size(img[]), ")")
end
function Base.show(io::IO, ::MIME"text/plain", d::ImageDisplay)
    img = getfield(d, :roi).image_roi[]
    println(io, "ImageDisplay: ", size(img), " ", eltype(img))
    sd = getfield(d, :roi).slicedata
    sd === nothing || isempty(sd) || println(io, "  slicedata: ", sd)
    cl = getfield(d, :clim)
    cl === nothing || println(io, "  clim: ", cl[])
    print(io, "  fields: ", join(propertynames(d), ", "))
end

function Base.show(io::IO, gui::ImageViewGUI)
    print(io, "ImageViewGUI(")
    f = getfield(gui, :frame)
    if f isa AbstractMatrix
        print(io, size(f), " grid")
    else
        print(io, "single canvas")
    end
    print(io, ")")
end

function Base.show(io::IO, r::ImageROI)
    print(io, "ImageROI(")
    print(io, eltype(r.image_roi[]), ", ", size(r.image_roi[]))
    r.slicedata === nothing || isempty(r.slicedata) || print(io, ", with slicedata")
    print(io, ")")
end

include("deprecated.jl")

"""
    closeall()

Closes all windows opened by ImageView.
"""
function closeall()
    for (w, _) in window_wrefs
        destroy(w)
    end
    empty!(window_wrefs)
    nothing
end

const window_wrefs = WeakKeyDict{Gtk4.GtkWindowLeaf,Nothing}()

"""
    imshow!(canvas, img) -> drawsignal
    imshow!(canvas, img::Observable, zr::Observable{ZoomRegion}) -> drawsignal
    imshow!(frame::Frame, canvas, img::Observable, zr::Observable{ZoomRegion}) -> drawsignal
    imshow!(..., anns=annotations())

Display the image `img`, in the specified `canvas`. Use the version
with `zr` if you have already turned on rubber-banding or other
pan/zoom interactivity for `canvas`. Returns the Observables `drawsignal`
used for updating the canvas.

If you supply `frame`, then the pixel aspect ratio will be set to that
of `pixelspacing(img)`.

With any of these forms, you may optionally supply `annotations`.

This only creates the `draw` method for `canvas`; mouse- or key-based
interactivity can be set up via [`imshow`](@ref) or, at a lower level,
using GtkObservables's tools:

- `init_zoom_rubberband`
- `init_zoom_scroll`
- `init_pan_scroll`
- `init_pan_drag`

# Example

```julia
using ImageView, GtkObservables, Gtk4, TestImages
# Create a window with a canvas in it
win = GtkWindow()
c = canvas(UserUnit)
push!(win, c)
# Load images
mri = testimage("mri")
# Display the image
imshow!(c, mri[:,:,1])
# Update with a different image
imshow!(c, mri[:,:,8])
"""
function imshow!(canvas::GtkObservables.Canvas{UserUnit},
                 imgsig::Observable,
                 zr::Observable{ZoomRegion{T}},
                 annotations::Annotations=annotations()) where T<:RInteger
    draw(canvas, imgsig, annotations) do cnvs, image, anns
        copy_with_restrict!(cnvs, image)
        set_coordinates(cnvs, zr[])
        draw_annotations(cnvs, anns)
    end
end

function imshow!(frame::Union{GtkFrame,GtkAspectFrame},
                 canvas::GtkObservables.Canvas{UserUnit},
                 imgsig::Observable,
                 zr::Observable{ZoomRegion{T}},
                 annotations::Annotations=annotations()) where T<:RInteger
    draw(canvas, imgsig, annotations) do cnvs, image, anns
        copy_with_restrict!(cnvs, image)
        set_coordinates(cnvs, zr[])
        set_aspect!(frame, image)
        draw_annotations(cnvs, anns)
        nothing
    end
end

# Without a ZoomRegion, there's no risk that the apsect ratio needs to
# change dynamically, so it can be set once and left. Consequently we
# don't need `frame` variants of the remaining methods.
function imshow!(canvas::GtkObservables.Canvas,
                 imgsig::Observable,
                 annotations::Annotations=annotations())
    draw(canvas, imgsig, annotations) do cnvs, image, anns
        copy_with_restrict!(cnvs, image)
        set_coordinates(cnvs, axes(image))
        draw_annotations(cnvs, anns)
    end
end

# Simple non-interactive image display
function imshow!(canvas::GtkObservables.Canvas,
                 img::AbstractMatrix,
                 annotations::Annotations=annotations())
    draw(canvas, annotations) do cnvs, anns
        copy_with_restrict!(cnvs, img)
        set_coordinates(cnvs, axes(img))
        draw_annotations(cnvs, anns)
    end
    nothing
end

function copy_with_restrict!(cnvs, img::AbstractMatrix)
    imgsz = size(img)
    while (imgsz[1] > 2*Graphics.height(cnvs) && imgsz[2] > 2*Graphics.width(cnvs))
        img = restrict(img)
        imgsz = size(img)
    end
    copy!(cnvs, img)
end

"""
    imshow(img; axes=(1,2), name="ImageView") -> disp::ImageDisplay
    imshow(img, clim; kwargs...) -> disp::ImageDisplay
    imshow(img, clim, zoomregion, slicedata, annotations; kwargs...) -> disp::ImageDisplay

Display the image `img` in a new window titled with `name`, returning an
[`ImageDisplay`](@ref) `disp` whose fields expose the Observables and
GtkObservables widgets that drive the GUI (see `propertynames(disp)`).
If the image is 3 or 4 dimensional, GUI controls will be
added for slicing along "extra" axes. By default the two-dimensional
slice containing axes 1 and 2 are shown, but that can be changed by
passing a different setting for `axes`.

If the image is grayscale, by default contrast is set by a
`scaleminmax` object whose end-points can be modified by
right-clicking on the image. If `clim == nothing`, the image's own
native contrast is used (`clamp01nan`).  You may also pass a custom
contrast function.

Finally, you may specify [`GtkObservables.ZoomRegion`](@ref) and
[`SliceData`](@ref) signals. See also [`roi`](@ref), as well as any
`annotations` that you wish to apply.

Other supported keyword arguments include:
- `scalei=identity` as an intensity-scaling function prior to display
- `aspect=:auto` to control the aspect ratio of the image
- `flipx=false`, `flipy=false` to flip axes
- `canvassize=nothing` to control the size of the window (`nothing` chooses based on image size)
"""
Compat.@constprop :none function imshow(@nospecialize(img::AbstractArray);
                axes=default_axes(img), name="ImageView", scalei=identity, aspect=:auto,
                kwargs...)
    imgmapped, kwargs = kwhandler(_mappedarray(scalei, img), axes; kwargs...)
    zr, sd = roi(imgmapped, axes)
    v = slice2d(imgmapped, zr[], sd)
    imshow(Base.inferencebarrier(imgmapped)::AbstractArray, default_clim(v), zr, sd; name=name, aspect=aspect, kwargs...)
end

imshow(img::AbstractVector; kwargs...) = (@nospecialize; imshow(reshape(img, :, 1); kwargs...))

function imshow(c::GtkObservables.Canvas, @nospecialize(img::AbstractMatrix), anns=annotations(); kwargs...)
    f = parent(widget(c))
    imshow(f, c, img, default_clim(img), roi(img, default_axes(img))..., anns; kwargs...)
end

Compat.@constprop :none function imshow(@nospecialize(img::AbstractArray), clim;
                axes = default_axes(img), name="ImageView", aspect=:auto, kwargs...)
    img, kwargs = kwhandler(img, axes; kwargs...)
    imshow(img, clim, roi(img, axes)...; name=name, aspect=aspect, kwargs...)
end

Compat.@constprop :none function imshow(@nospecialize(img::AbstractArray), clim,
                zr::Observable{ZoomRegion{T}}, sd::SliceData,
                anns=annotations();
                name="ImageView", aspect=:auto, canvassize::Union{Nothing,Tuple{Int,Int}}=nothing) where T
    v = slice2d(img, zr[], sd)
    ps = map(abs, pixelspacing(v))
    if canvassize === nothing
        canvassize = default_canvas_size(fullsize(zr[]), ps[2]/ps[1])
    end
    gui = imshow_gui(canvassize, sd; name=name, aspect=aspect)
    gui.hoverinfo = on(gui.canvas.mouse.motion) do btn
        hoverinfo(gui.status, btn, img, sd)
    end
    gui.zoomregion_info = on(zr; update=true) do z
        viewinfo(gui.viewlabel, z, sd)
    end

    roi_ = imshow(gui.frame, gui.canvas, img,
                  wrap_signal(clim), zr, sd, anns)

    disp = ImageDisplay(gui, roi_, clim, anns)
    GtkObservables.gc_preserve(gui.window, disp)
    return disp
end

function imshow(frame::Union{Gtk4.GtkFrame,Gtk4.GtkAspectFrame}, canvas::GtkObservables.Canvas,
                @nospecialize(img::AbstractArray), clim::Union{Nothing,Observable{<:CLim}},
                zr::Observable{ZoomRegion{T}}, sd::SliceData,
                anns::Annotations=annotations()) where T
    imgsig = map(zr, sd.signals...) do r, s...
        @nospecialize
        while length(s) < 2
            s = (s..., 1)
        end
        for (h, ann) in anns[]
            setvalid!(ann, s...)
        end
        slice2d(img, r, sd)
    end
    set_aspect!(frame, imgsig[])
    imgc = prep_contrast(canvas, imgsig, clim)
    GtkObservables.gc_preserve(frame, imgc)
    # If there is an error in one of the functions being mapped elementwise, we often don't
    # discover it until it triggers an error inside `Gtk4.draw`. Check for problems here so
    # such errors become easier to debug.
    if !supported_eltype(imgc[])
        !supported_eltype(imgsig[]) && error("got unsupported eltype $(eltype(imgsig[])) in creating slice")
        error("got unsupported eltype $(eltype(imgc[])) in preparing the contrast")
    end

    roi_ = imshow(frame, canvas, imgc, zr, anns)
    roi_.slicedata = sd
    roi_
end

# For things that are not AbstractArrays, we don't offer the clim
# option.  We also don't display hoverinfo, as there is no guarantee
# that one can quickly compute intensities at a point.
Compat.@constprop :none function imshow(img;
                axes = default_axes(img), name="ImageView", aspect=:auto)
    @nospecialize
    zr, sd = roi(img, axes)
    imshow(img, zr, sd; name=name, aspect=aspect)
end

Compat.@constprop :none function imshow(img,
                zr::Observable{ZoomRegion{T}}, sd::SliceData,
                anns=annotations();
                name="ImageView", aspect=:auto) where T
    @nospecialize
    v = slice2d(img, zr[], sd)
    ps = map(abs, pixelspacing(v))
    csz = default_canvas_size(fullsize(zr[]), ps[2]/ps[1])
    gui = imshow_gui(csz, sd; name=name, aspect=aspect)

    roi_ = imshow(gui.frame, gui.canvas, img, zr, sd, anns)

    disp = ImageDisplay(gui, roi_, nothing, anns)
    GtkObservables.gc_preserve(gui.window, disp)
    return disp
end

function imshow(frame::Union{GtkFrame,GtkAspectFrame}, canvas::GtkObservables.Canvas,
                img, zr::Observable{ZoomRegion{T}}, sd::SliceData,
                anns::Annotations=annotations()) where T
    @nospecialize
    imgsig = map(zr, sd.signals...) do r, s...
        @nospecialize
        slice2d(img, r, sd)
    end
    set_aspect!(frame, imgsig[])
    GtkObservables.gc_preserve(frame, imgsig)

    roi_ = imshow(frame, canvas, imgsig, zr, anns)
    roi_.slicedata = sd
    GtkObservables.gc_preserve(frame, roi_)
    roi_
end

function close_cb(::Ptr, par, win)
    @idle_add Gtk4.destroy(win)
    nothing
end

function closeall_cb(::Ptr, par, win)
    @idle_add closeall()
    nothing
end

function fullscreen_cb(aptr::Ptr, par, win)
    gv=Gtk4.GLib.GVariant(par)
    a=convert(Gtk4.GLib.GSimpleAction, aptr)
    if gv[Bool]
        @idle_add Gtk4.fullscreen(win)
    else
        @idle_add Gtk4.unfullscreen(win)
    end
    Gtk4.GLib.set_state(a, gv)
    nothing
end

"""
    gui = imshow_gui(canvassize, gridsize=(1,1); name="ImageView", aspect=:auto, slicedata=SliceData{false}()) -> gui::ImageViewGUI

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
Compat.@constprop :none function imshow_gui(canvassize::Tuple{Int,Int},
                    gridsize::Tuple{Int,Int} = (1,1);
                    name = "ImageView", aspect=:auto,
                    slicedata::SliceData=SliceData{false}())
    winsize = canvas_size(screen_size(), map(*, canvassize, gridsize))
    win = GtkWindow(name, winsize...)
    ag = Gtk4.GLib.GSimpleActionGroup()
    m = Gtk4.GLib.GActionMap(ag)
    push!(win, Gtk4.GLib.GActionGroup(ag), "win")
    Gtk4.GLib.add_action(m, "close", close_cb, win)
    Gtk4.GLib.add_action(m, "closeall", closeall_cb, nothing)
    Gtk4.GLib.add_stateful_action(m, "fullscreen", false, fullscreen_cb, win)
    sc = GtkShortcutController(win)
    Gtk4.add_action_shortcut(sc,Sys.isapple() ? "<Meta>W" : "<Control>W", "win.close")
    Gtk4.add_action_shortcut(sc,Sys.isapple() ? "<Meta><Shift>W" : "<Control><Shift>W", "win.closeall")
    Gtk4.add_action_shortcut(sc,Sys.isapple() ? "<Meta><Shift>F" : "F11", "win.fullscreen")

    window_wrefs[win] = nothing
    signal_connect(win, :destroy) do w
        delete!(window_wrefs, win)
    end
    vbox = GtkBox(:v)
    push!(win, vbox)
    if gridsize == (1,1)
        frames, canvases = frame_canvas(aspect)
        g = frames
    else
        g, frames, canvases = canvasgrid(gridsize, aspect)
    end
    push!(vbox, g)
    cbox = GtkCenterBox()
    push!(vbox, cbox)
    status = GtkLabel("")
    cbox[:start] = status
    viewlabel = GtkLabel(""; selectable = true)
    Gtk4.ellipsize(viewlabel, Gtk4.Pango.EllipsizeMode_MIDDLE)
    cbox[:end] = viewlabel

    gui = ImageViewGUI(win, vbox, frames, canvases, status, viewlabel)

    # Add the player controls
    if !isempty(slicedata)
        players = [player(slicedata.signals[i], axisvalues(slicedata.axs[i])[1]; id=i) for i = 1:length(slicedata)]
        gui.players = players
        hbox = GtkBox(:h)
        for p in players
            push!(hbox, frame(p))
        end
        push!(gui.vbox, hbox)
    end

    gui
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
Compat.@constprop :none function canvasgrid(gridsize::Tuple{Int,Int}, aspect=:auto)
    g = GtkGrid()
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

Compat.@constprop :none function frame_canvas(aspect)
    f = aspect==:none ? GtkFrame() : GtkAspectFrame(0.5, 0.5, 1, false)
    Gtk4.G_.set_css_classes(f, ["squared"])  # remove rounded corners (see __init__)
    set_gtk_property!(f, :hexpand, true)
    set_gtk_property!(f, :vexpand, true)
    c = canvas(UserUnit,10,10)  # set minimum size of 10x10 pixels
    f[] = widget(c)
    f, c
end

"""
    imshow(canvas, imgsig::Observable) -> roi::ImageROI
    imshow(canvas, imgsig::Observable, zr::Observable{ZoomRegion}) -> roi::ImageROI
    imshow(frame::Frame, canvas, imgsig::Observable, zr::Observable{ZoomRegion}) -> roi::ImageROI

Display `imgsig` (a `Observable` of an image) in `canvas`, setting up
panning and zooming. Optionally include a `frame` for preserving
aspect ratio. `imgsig` must be two-dimensional (but can be a
Observable-view of a higher-dimensional object).

# Example

```julia
using ImageView, TestImages, Gtk4
mri = testimage("mri");
# Create a canvas `c`. There are other approaches, like stealing one from a previous call
# to `imshow`, or using GtkObservables directly.
gui = imshow_gui((300, 300))
c = gui.canvas;
# To see anything you have to call `showall` on the window (once)
# Create the image Observable
imgsig = Observable(mri[:,:,1]);
# Show it
imshow(c, imgsig)
# Now anytime you want to update, just reset with a new image
imgsig[] = mri[:,:,8]
```
"""
function imshow(canvas::GtkObservables.Canvas{UserUnit},
                imgsig::Observable,
                zr::Observable{ZoomRegion{T}}=Observable(ZoomRegion(imgsig[])),
                anns::Annotations=annotations()) where T<:RInteger
    @nospecialize
    zoomrb = init_zoom_rubberband(canvas, zr)
    zooms = init_zoom_scroll(canvas, zr)
    pans = init_pan_scroll(canvas, zr)
    pand = init_pan_drag(canvas, zr)
    redraw = imshow!(canvas, imgsig, zr, anns)
    roi_ = ImageROI(imgsig, zr, zoomrb, zooms, pans, pand, redraw)
    GtkObservables.gc_preserve(widget(canvas), roi_)
    roi_
end

function imshow(frame::Union{GtkFrame,GtkAspectFrame},
                canvas::GtkObservables.Canvas{UserUnit},
                imgsig::Observable,
                zr::Observable{ZoomRegion{T}},
                anns::Annotations=annotations()) where T<:RInteger
    @nospecialize
    zoomrb = init_zoom_rubberband(canvas, zr)
    zooms = init_zoom_scroll(canvas, zr)
    pans = init_pan_scroll(canvas, zr)
    pand = init_pan_drag(canvas, zr)
    redraw = imshow!(frame, canvas, imgsig, zr, anns)
    roi_ = ImageROI(imgsig, zr, zoomrb, zooms, pans, pand, redraw)
    GtkObservables.gc_preserve(widget(canvas), roi_)
    roi_
end

"""
    imshowlabeled(img, label)

Display `img`, but showing the pixel's `label` rather than the color
value in the status bar.
"""
function imshowlabeled(img::AbstractArray, label::AbstractArray; proplist...)
    @nospecialize
    axes(img) == axes(label) || throw(DimensionMismatch("axes $(axes(label)) of label array disagree with axes $(axes(img)) of the image"))
    disp = imshow(img; proplist...)
    gui = disp.gui
    sd = disp.roi.slicedata
    off(gui.hoverinfo)
    gui.hoverinfo = on(gui.canvas.mouse.motion) do btn
        hoverinfo(gui.status, btn, label, sd)
    end
    disp
end

function hoverinfo(lbl, btn, img, sd::SliceData{transpose}) where transpose
    io = IOBuffer()
    y, x = round(Int, btn.position.y.val), round(Int, btn.position.x.val)
    axes = sliceinds(img, transpose ? (x, y) : (y, x), makeslices(sd)...)
    if checkbounds(Bool, img, axes...)
        print(io, '[', y, ',', x, "] ")
        show(IOContext(io, :compact=>true), img[axes...])
        Gtk4.label(lbl, String(take!(io)))
    else
        Gtk4.label(lbl, "")
    end
end

function viewinfo(lbl, zr, sd::SliceData{transpose}) where transpose
    io = IOBuffer()
    if zr.currentview == zr.fullview
        print(io, "")
    else
        print(io, "view: ")
        x, y = transpose ? (zr.currentview.x, zr.currentview.y) : (zr.currentview.y, zr.currentview.x)
        print(io, '[', x.left, ':', x.right, ',', y.left, ':', y.right, ']')
    end
    Gtk4.label(lbl, String(take!(io)))
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
    Observable(CLim(saferound(gray(minval)), saferound(gray(maxval))))
end

# The method above began throwing an error for integers >1 in mid 2025
# This restores the previous "clamping" behavior
function _deflt_clim(img::AbstractMatrix{T}) where {T<:Integer}
    Observable(CLim(0.0, 1.0))
end

function _deflt_clim(img::AbstractMatrix{T}) where {T<:AbstractRGB}
    minval = RGB(0.0,0.0,0.0)
    maxval = RGB(1.0,1.0,1.0)
    Observable(CLim(minval, maxval))
end

saferound(x::Integer) = convert(RInteger, x)
saferound(x) = x

default_axes(::AbstractVector) = (1,)
default_axes(img) = (1, 2)
default_axes(img::AxisArray) = axisnames(img)[[1,2]]

#default_view(img) = view(img, :, :, ntuple(d->1, ndims(img)-2)...)
#default_view(img::Observable) = default_view(img[])

# default_slices(img) = ntuple(d->PlayerInfo(Observable(1), axes(img, d+2)), ndims(img)-2)

function histsignals(enabled::Observable{Bool}, img::Observable, clim::Observable{CLim{T}}) where {T<:GrayLike}
    image, cl = img[], clim[]
    hist_type = promote_type(T, eltype(image))
    if hist_type == Any
        error("got unsupported eltype Any in preparing the contrast")
    end
    Th = float(hist_type)
    function computehist(image, cl)
        smin, smax = valuespan(image)
        smin = float(min(smin, cl.min))
        smax = float(max(smax, cl.max))
        rng = LinRange(Th(smin), Th(smax), 300)
        fit(Histogram, mappedarray(nanz, vec(channelview(image))), rng; closed=:right)
    end
    histsig = Observable(enabled[] ? computehist(image, cl) :
                                     Histogram(LinRange(Th(cl.min), Th(cl.max), 2), [length(image)], :right, false))
    map!(histsig, img, enabled) do image, en  # `enabled` fixes issue #168
        if en
            computehist(image, clim[])
        else
            histsig[]
        end
    end
    return [histsig]
end

channel_clim(f, clim::CLim{C}) where {C<:Colorant} = CLim(f(clim.min), f(clim.max))
channel_clims(clim::CLim{T}) where {T<:AbstractRGB} = map(f->channel_clim(f, clim), (red, green, blue))

function mapped_channel_clims(clim::Observable{CLim{T}}) where {T<:AbstractRGB}
    inits = channel_clims(clim[])
    rsig = map!(x->channel_clim(red, x), Observable(inits[1]), clim)
    gsig = map!(x->channel_clim(green, x), Observable(inits[1]), clim)
    bsig = map!(x->channel_clim(blue, x), Observable(inits[1]), clim)
    return [rsig;gsig;bsig]
end

function histsignals(enabled::Observable{Bool}, img::Observable, clim::Observable{CLim{T}}) where {T<:AbstractRGB}
    rv = map(x->mappedarray(red, x), img)
    gv = map(x->mappedarray(green,x), img)
    bv = map(x->mappedarray(blue, x), img)
    cls = mapped_channel_clims(clim) #note currently this gets called twice, also in contrast gui creation (a bit inefficient/awkward)
    histsigs = []
    push!(histsigs, histsignals(enabled, rv, cls[1])[1])
    push!(histsigs, histsignals(enabled, gv, cls[2])[1])
    push!(histsigs, histsignals(enabled, bv, cls[3])[1])
    return histsigs
end

function scalechannels(::Type{Tout}, cmin::AbstractRGB{T}, cmax::AbstractRGB{T}) where {T,Tout}
    r = scaleminmax(T, red(cmin), red(cmax))
    g = scaleminmax(T, green(cmin), green(cmax))
    b = scaleminmax(T, blue(cmin), blue(cmax))
    return x->Tout(nanz(r(red(x))), nanz(g(green(x))), nanz(b(blue(x))))
end
scalechannels(::Type{Tout}, cmin::C, cmax::C) where {Tout, C<:Union{Number,AbstractGray}} = scaleminmax(Tout, cmin, cmax)

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

function prep_contrast(@nospecialize(img::Observable), clim::Observable{CLim{T}}) where {T}
    # Set up the signals to calculate the histogram of intensity
    enabled = Observable(false) # skip hist calculation if the contrast gui isn't open
    histsigs = histsignals(enabled, img, clim)
    # Return a signal corresponding to the scaled image
    imgc = map(img, clim) do image, cl
        cmin, cmax = safeminmax(cl.min, cl.max)
        smm = scalechannels(outtype(T), cmin, cmax)
        mappedarray(smm, image)
    end
    enabled, histsigs, imgc
end

outtype(::Type{T}) where T<:GrayLike         = Gray{N0f8}
outtype(::Type{C}) where C<:Color            = RGB{N0f8}
outtype(::Type{C}) where C<:TransparentColor = RGBA{N0f8}

function prep_contrast(canvas, @nospecialize(img::Observable), clim::Observable{CLim{T}}) where T
    enabled, histsigs, imgsig = prep_contrast(img, clim)
    # Set up the right-click to open the contrast gui
    push!(canvas.preserved, create_contrast_popup(canvas, enabled, histsigs, clim))
    imgsig
end

prep_contrast(canvas, img::Observable, f) =
    map(image->mappedarray(f, image), img)
prep_contrast(canvas, img::Observable{A}, ::Nothing) where {A<:AbstractArray} =
    prep_contrast(canvas, img, clamp01nan)
prep_contrast(canvas, img::Observable, ::Nothing) = img

nanz(x) = ifelse(isnan(x), zero(x), x)
nanz(x::FixedPoint) = x
nanz(x::Integer) = x

const menuxml = """
<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <menu id="context_menu">
    <item>
      <attribute name="label">Contrast...</attribute>
      <attribute name="action">canvas.contrast_gui</attribute>
    </item>
    <item>
      <attribute name="label">Save to file...</attribute>
      <attribute name="action">canvas.save</attribute>
    </item>
    <item>
      <attribute name="label">Copy to clipboard</attribute>
      <attribute name="action">canvas.copy</attribute>
    </item>
  </menu>
</interface>
"""

function create_contrast_popup(canvas, enabled, hists, clim)
    b = GtkBuilder(menuxml, -1)
    menumodel = b["context_menu"]::Gtk4.GLib.GMenuLeaf
    popupmenu = GtkPopoverMenu(menumodel)
    Gtk4.parent(popupmenu, widget(canvas))
    push!(canvas.preserved, on(canvas.mouse.buttonpress) do btn
        if btn.button == 3 && btn.clicktype == BUTTON_PRESS
            x,y = GtkObservables.convertunits(DeviceUnit, canvas, btn.position.x, btn.position.y)
            Gtk4.G_.set_pointing_to(popupmenu,Ref(Gtk4._GdkRectangle(round(Int32,x.val),round(Int32,y.val),1,1)))
            popup(popupmenu)
        end
    end)
    contrast_gui_action = Gtk4.GLib.GSimpleAction("contrast_gui", Nothing)
    push!(Gtk4.GLib.GActionMap(canvas.action_group), Gtk4.GLib.GAction(contrast_gui_action)) # replaces the old one if it exists
    signal_connect(contrast_gui_action, :activate) do a, par
        enabled[] = true
        @idle_add contrast_gui(enabled, hists, clim)
    end
end

function dummy_histsig(clim::Observable{CLim{T}}; floor=nothing) where {T<:GrayLike}
    Th = float(T)
    cl = clim[]
    lo, hi = Th(cl.min), Th(cl.max)
    if !(lo < hi)
        lo, hi = zero(Th), one(Th)
    end
    span = hi - lo
    rnglo = floor === nothing ? lo - span/2 : max(Th(floor), lo - span/2)
    rng = LinRange(rnglo, hi + span/2, 300)
    Observable(Histogram(rng, zeros(Int, 299), :right, false))
end

dummy_histsigs(clim::Observable{CLim{T}}; floor=nothing) where {T<:GrayLike} =
    [dummy_histsig(clim; floor)]

dummy_histsigs(clim::Observable{CLim{T}}; floor=nothing) where {T<:AbstractRGB} =
    [dummy_histsig(map(x->channel_clim(red, x), clim); floor),
     dummy_histsig(map(x->channel_clim(green, x), clim); floor),
     dummy_histsig(map(x->channel_clim(blue, x), clim); floor)]

"""
    setup_contrast_popup!(canvas, clim; img=nothing)

Set up a right-click context menu on `canvas` that allows interactive
adjustment of `clim` via a contrast GUI window. If `img` is an
`Observable` wrapping an array compatible with `clim`, a histogram of
pixel intensities is computed and shown whenever the GUI is opened.
Without `img`, the GUI shows sliders only (no histogram).

This is a lower-level complement to [`imshow`](@ref), useful when
contrast is managed internally by the image type but an interactive
right-click popup is still desired.
"""
function setup_contrast_popup!(canvas, clim::Observable{CLim{T}};
                                img::Union{Nothing,Observable}=nothing,
                                floor=nothing) where T
    enabled = Observable(false)
    histsigs = img === nothing ? dummy_histsigs(clim; floor) : histsignals(enabled, img, clim)
    push!(canvas.preserved, create_contrast_popup(canvas, enabled, histsigs, clim))
    return canvas
end

function map_image_roi(@nospecialize(img), zr::Observable{ZoomRegion{T}}, slices...) where T
    map(zr, slices...) do r, s...
        cv = r.currentview
        view(img, UnitRange{Int}(cv.y), UnitRange{Int}(cv.x), s...)
    end
end
map_image_roi(img::Observable, zr::Observable{ZoomRegion{T}}, slices...) where {T} = img

function set_aspect!(frame::GtkAspectFrame, image)
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
Compat.@constprop :none function canvas_size(win::Gtk4.GtkWindowLeaf, requestedsize_xy; minsize=100)
    ssz = screen_size(win)
    canvas_size(map(x->0.6*x, ssz), requestedsize_xy; minsize=minsize)
end

Compat.@constprop :none function canvas_size(screensize_xy, requestedsize_xy; minsize=100)
    f = minimum(map(/, screensize_xy, requestedsize_xy))
    if f > 1
        fmn = maximum(map(/, (minsize,minsize), requestedsize_xy))
        f = max(1, min(f, fmn))
    end
    (round(Int, f*requestedsize_xy[1]), round(Int, f*requestedsize_xy[2]))
end

Compat.@constprop :none function kwhandler(@nospecialize(img), axs; flipx=false, flipy=false, kwargs...)
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

wrap_signal(x) = Observable(x)
wrap_signal(x::Observable) = x
wrap_signal(::Nothing) = nothing

function supported_eltype(@nospecialize(img))
    T = eltype(img)
    return T <: Union{Number,Colorant} && T !== Union{}
end

include("link.jl")
include("contrast_gui.jl")
include("annotations.jl")

function __init__()
    if !Gtk4.initialized[]
        error("Gtk4 not initialized")
        return
    end
    # by default, GtkFrame and GtkAspectFrame use rounded corners
    # the way to override this is via custom CSS
    css="""
        .squared {border-radius: 0;}
    """
    cssprov=GtkCssProvider(css)
    push!(GdkDisplay(), cssprov, Gtk4.STYLE_PROVIDER_PRIORITY_APPLICATION)
end

using PrecompileTools
@compile_workload begin
    for T in (N0f8, N0f16, Float32)
        for C in (Gray, RGB)
            img = rand(C{T}, 2, 2)
            if !Gtk4.initialized[]
                @warn("ImageView precompile skipped: Gtk4 could not be initialized (are you on a headless system?)")
                return
            end
            imshow(img)
            clim = ImageView.default_clim(img)
            imgsig = Observable(img)
            enabled, histsig, imgc = ImageView.prep_contrast(imgsig, clim)
            enabled[] = true
            ImageView.contrast_gui(enabled, histsig, clim)
        end
    end
    closeall()   # this is critical: you don't want to precompile with window_wrefs loaded with junk (dangling window pointers from closed session)
    sleep(1)   # avoid a "waiting for IO to finish" warning on 1.10
end

end # module
