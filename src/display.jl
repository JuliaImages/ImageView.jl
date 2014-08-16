using ImageView.Navigation

import Base: show
import Base.Graphics: width, height, fill, set_coords, xmin, xmax, ymin, ymax


# Since we have Tk available, don't force the user to type a filename
import Images.imread
imread() = imread(GetOpenFile())

import Images.scaleinfo
function scaleinfo(cs::ImageContrast.ContrastSettings, scalei::ScaleInfo, img)
    if cs.min == nothing && cs.max == nothing
        return scalei
    else
        return scaleminmax(img, cs.min, cs.max)
    end
end

@linux_only const default_perimeter = RGB(0.85,0.85,0.85)
@osx_only const default_perimeter = RGB(0.93, 0.93, 0.93)
@windows_only const default_perimeter = RGB(1,1,1)  # untested

## Type for storing information about the rendering canvas
# perimeter is the color used around the edges of the image; background is used
# "behind" the image (relevant only if it has transparency)
# render has syntax
#    render!(buf, img)
type ImageCanvas
    render!::Function        # function to fill a Uint32 buffer with image data
    aspect_x_per_y           # relative scaling of the two axes (unconstrained = nothing)
    background               # nothing, RGB color, or checkerboard pattern
    perimeter                # RGB color
    transpose::Bool
    flipx::Bool
    flipy::Bool
    surfaceformat::Int32     # The Cairo format (e.g., Cairo.FORMAT_ARGB32)
    annotations::Dict{Uint, AbstractAnnotation}
    handles::Dict{Symbol, Any}
    c::Canvas                # canvas for rendering image
    surface::CairoSurface    # source surface of the image (changes with zoom region)
    renderbuf::Array{Uint32} # intermediate used if transpose is true
    canvasbb::BoundingBox    # drawing region within canvas, in device coordinates
    navigationstate
    navigationctrls

    function ImageCanvas(fmt::Int32, props::Dict)
        ps = get(props, :pixelspacing, nothing)
        aspect_x_per_y = is(ps, nothing) ? nothing : ps[1]/ps[2]
        if haskey(props, :render!)
            render! = props[:render!]
        else
            if haskey(props, :clim)
                clim = props[:clim]
                render! = (buf, img) -> uint32color!(buf, img, scaleminmax(img, clim[1], clim[2]))
            elseif haskey(props, :scalei)
                render! = (buf, img) -> uint32color!(buf, img, props[:scalei])
            else
                render! = uint32color!
            end
        end
        background = get(props, :background, fmt == Cairo.FORMAT_ARGB32 ? checker(32) : nothing)
        perimeter = get(props, :perimeter, default_perimeter)
        transpose = props[:transpose]
        flipx = get(props, :flipx, false)
        flipy = get(props, :flipy, false)
        new(render!, aspect_x_per_y, background, perimeter, transpose, flipx, flipy, fmt, Dict{Uint,AbstractAnnotation}(), Dict{Symbol,Any}())
        # c, surface, renderbuf, and canvasbb will be initialized later
    end
end

show(io::IO, imgc::ImageCanvas) = print(io, "ImageCanvas")

canvas(imgc::ImageCanvas) = imgc.c

parent(imgc::ImageCanvas) = Tk.parent(imgc.c)

toplevel(imgc::ImageCanvas) = Tk.toplevel(canvas(imgc))

function setbb!(imgc::ImageCanvas, w, h)
    if !is(imgc.aspect_x_per_y, nothing)
        wc = width(imgc.c)
        hc = height(imgc.c)
        sx = min(wc/w, imgc.aspect_x_per_y*hc/h)
        sy = sx/imgc.aspect_x_per_y
        wdraw = sx*w
        hdraw = sy*h
        xmin = (wc-wdraw)/2
        ymin = (hc-hdraw)/2
        imgc.canvasbb = BoundingBox(xmin, xmin+wdraw, ymin, ymin+hdraw)
    else
        imgc.canvasbb = BoundingBox(0, width(imgc.c), 0, height(imgc.c))
    end
    imgc
end

# Handle z and t slicing, and zooming in x and y
type ImageSlice2d{A<:AbstractImage}
    imslice::A
    pdims::Vector{Int}
    indexes::Vector{RangeIndex}
    dims::Vector{Int}
    zoombb::BoundingBox
    zindex::Int
    tindex::Int
    xdim::Int
    ydim::Int
    zdim::Int
    tdim::Int
end

function ImageSlice2d(img::AbstractImage, pdims::Vector{Int}, indexes, dims, bb::BoundingBox, zindex::Integer, tindex::Integer, xdim::Integer, ydim::Integer, zdim::Integer, tdim::Integer)
    assert2d(img)
    ImageSlice2d{typeof(img)}(img, pdims, RangeIndex[indexes...], Int[dims...], bb, int(zindex), int(tindex), int(xdim), int(ydim), int(zdim), int(tdim))
end

function show(io::IO, img2::ImageSlice2d)
    print(io, "ImageSlice2d: zoom = ", img2.zoombb)
    if img2.zdim > 0
        print(io, ", z = ", img2.zindex)
    end
    if img2.tdim > 0
        print(io, ", t = ", img2.tindex)
    end
end

function ImageSlice2d(img::AbstractArray, props::Dict)
    sd = sdims(img)
    if !(2 <= sd <= 3)
        error("Only two or three spatial dimensions are permitted")
    end
    if !isa(img, AbstractImage)
        img = Image(img, ["colordim" => colordim(img), "spatialorder" => spatialorder(img), "colorspace" => colorspace(img)])
    end
    # Determine how dimensions map to x, y, z, t
    xy = get(props, :xy, Images.xy)
    cs = coords_spatial(img)
    p = spatialpermutation(xy, img)
    xdim = cs[p[1]]
    ydim = cs[p[2]]
    zdim = (sd == 2) ? 0 : cs[p[3]]
    tdim = timedim(img)
    # Deal with pixelspacing here
    if !haskey(props, :pixelspacing)
        if haskey(img, "pixelspacing")
            props[:pixelspacing] = img["pixelspacing"][p]
        end
    end
    props[:transpose] = p[1] > p[2]
    # Start at z=1, t=1
    pindexes = parentindexes(data(img))
    pdims = parentdims(data(img))
    indexes = ntuple(ndims(img), i -> (i == zdim || i == tdim) ? 1 : (1:size(img, i)))
    imslice = sliceim(img, indexes...)
    bb = BoundingBox(0, size(img, xdim), 0, size(img, ydim))
    sz = size(imslice)
    ImageSlice2d(imslice, pdims, pindexes, size(imslice), bb, 1, 1, xdim, ydim, zdim, tdim)
end

parentdims(A::AbstractArray) = [1:ndims(A)]
parentdims(A::SubArray) = Base.parentdims(A)

function _reslice!(img2::ImageSlice2d)
    newindexes = copy(img2.indexes)
    bb = img2.zoombb
    newindexes[img2.xdim] = newindexes[img2.xdim][ifloor(bb.xmin)+1:iceil(bb.xmax)]
    newindexes[img2.ydim] = newindexes[img2.ydim][ifloor(bb.ymin)+1:iceil(bb.ymax)]
    if img2.zdim > 0
        newindexes[img2.zdim] = newindexes[img2.zdim][img2.zindex]
    end
    if img2.tdim > 0
        newindexes[img2.tdim] = newindexes[img2.tdim][img2.tindex]
    end
    img2.imslice.data.indexes = tuple(newindexes...)
    j = 1
    for i = 1:length(newindexes)
        if !isa(newindexes[i], Int)
            img2.dims[j] = length(newindexes[i])
            j += 1
        end
    end
    img2.imslice.data.dims = tuple(img2.dims...)
    resetfirst!(img2.imslice.data)
    img2
end

function slice2!(img2::ImageSlice2d, z::Int, t::Int)
    img2.zindex = z
    img2.tindex = t
    _reslice!(img2)
end

function zoom2!(img2::ImageSlice2d, bb::BoundingBox)
    img2.zoombb = bb
    _reslice!(img2)
end

function zoom2!(img2::ImageSlice2d)
    img2.zoombb = BoundingBox(0,length(img2.indexes[img2.xdim]),0,length(img2.indexes[img2.ydim]))
    _reslice!(img2)
end

# 
width(img2::ImageSlice2d)  = iceil(xmax(img2))-ifloor(xmin(img2))
height(img2::ImageSlice2d) = iceil(ymax(img2))-ifloor(ymin(img2))
xmin(img2::ImageSlice2d) = xmin(img2.zoombb)
xmax(img2::ImageSlice2d) = xmax(img2.zoombb)
ymin(img2::ImageSlice2d) = ymin(img2.zoombb)
ymax(img2::ImageSlice2d) = ymax(img2.zoombb)
sizex(img2::ImageSlice2d) = length(img2.indexes[img2.xdim])
sizey(img2::ImageSlice2d) = length(img2.indexes[img2.ydim])
sizez(img2::ImageSlice2d) = (img2.zdim > 0) ? length(img2.indexes[img2.zdim]) : 1
sizet(img2::ImageSlice2d) = (img2.tdim > 0) ? length(img2.indexes[img2.tdim]) : 1
xrange(img2::ImageSlice2d) = (xmin(img2), xmax(img2))
yrange(img2::ImageSlice2d) = (ymin(img2), ymax(img2))

# Valid properties:
#   render!: supply a function render!(buf, imgslice) that fills Uint32 buffer for display
#   xy: {"y", "x"} chooses orientation of display (which dims are horizontal, vertical)
#   flipx, flipy: set to true if you want to invert one or both axes
#   pixelspacing: [1,1] enforces uniform aspect ratio (will default to use from img if available)
#   name: a string giving the window name
#   background, perimeter: colors

function view{A<:AbstractArray}(img::A; proplist...)
    # Convert keyword list to dictionary
    props = Dict{Symbol,Any}()
    sizehint(props, length(proplist))
    for (k,v) in proplist
        props[k] = v
    end
    # Extract relevant information from the image and properties
    img2 = ImageSlice2d(img, props)
    imgc = ImageCanvas(cairo_format(img), props)
    w = width(img2)
    h = height(img2)
    zmax = sizez(img2)
    tmax = sizet(img2)
    havecontrols = zmax > 1 || tmax > 1
    # Determine the desired window size
    # (the actual size may be smaller, depending on screen size)
    ww, wh = rendersize(w, h, imgc.aspect_x_per_y)
    whfull = wh
    if havecontrols
        btnsz, pad = Navigation.widget_size()
        whfull += btnsz[2] + 2*pad
    end
    # Create the window and the canvas for displaying the image
    win = Toplevel(get(props, :name, "ImageView"), ww, whfull, false)
    framec = OS_NAME == :Darwin ? Frame(win, padding = 30) : Frame(win) # helps with accidental rubberband on resize
    grid(framec, 1, 1, sticky="nsew")
    grid_rowconfigure(win, 1, weight=1) # scale this cell when the window resizes
    grid_columnconfigure(win, 1, weight=1)
    c = Canvas(framec, ww, wh)
    imgc.c = c
    # Place the canvas and set its resize properties
    grid(c, 1, 1, sticky="nsew")        # fill the edges of its cell on all 4 sides
    grid_rowconfigure(framec, 1, weight=1) # scale this cell when the window resizes
    grid_columnconfigure(framec, 1, weight=1)
    # If necessary, create the navigation controls
    lastrow = 1
    if havecontrols
        ctrls = NavigationControls()
        state = NavigationState(zmax, tmax)
        showframe = state -> reslice(imgc, img2, state)
        fctrls = Frame(win)
        grid(fctrls, lastrow+=1, 1, sticky="ew")  # place the controls below the image
        init_navigation!(fctrls, ctrls, state, showframe)
        if zmax > 1
            try
                # Replace the z label with the name of the z coordinate
                cs = coords_spatial(img)
                ilabel = setdiff(cs, [img2.xdim,img2.ydim])[1]
                ilabel = find(cs .== ilabel)[1]
                set_value(ctrls.textz, spatialorder(img)[ilabel]*":")
            catch
            end
        end
        imgc.navigationstate = state
        imgc.navigationctrls = ctrls
        # Bind mousewheel events to navigation
        bindwheel(c, "Alt", (path,delta)->reslicet(imgc,img2,ctrls,state,int(delta)))
        bindwheel(c, "Alt-Control", (path,delta)->reslicez(imgc,img2,ctrls,state,int(delta)))
    end
    # Create the x,y position reporter
    fnotify = Frame(win)
    grid(fnotify, lastrow+=1, 1, sticky="ew")
    xypos = Label(fnotify)
    imgc.handles[:pointerlabel] = xypos
    grid(xypos, 1, 1, sticky="ne")
    # Set up the rendering
    set_visible(win, true)
#     ctx = getgc(c)  # force initialization of canvas
    allocate_surface!(imgc, w, h)
    create_callbacks(imgc, img2)
    c.mouse.motion = (path,x,y) -> updatexylabel(xypos, imgc, img2, x, y)
    if imgc.render! == uint32color! && colorspace(img) == "Gray"
        menu = Menu(framec)
        if haskey(img, "scalei")
            cs = ImageContrast.ContrastSettings(nothing,nothing)
            imgc.render! = (buf,img) -> uint32color!(buf, img, scaleinfo(cs, img["scalei"], img))
        else
            clim = climdefault(img)
            cs = ImageContrast.ContrastSettings(clim[1], clim[2])
            imgc.render! = (buf,img) -> uint32color!(buf, img, scaleminmax(img, cs.min, cs.max))
        end
        menu_contrast = menu_add(menu, "Contrast...", path -> ImageContrast.contrastgui(img2.imslice, cs, x->redraw(imgc, img2)))
        tk_popup(c, menu)
    end
    # render the initial state
    rerender(imgc, img2)
    resize(imgc, img2)
    Tk.configure(imgc.c)
    imgc, img2
end

# Display a labeled image: in the status bar that shows information about the pixel under the mouse pointer,
# display the label value rather than the pixel value.
function viewlabeled(img::AbstractArray, label::AbstractArray; proplist...)
    imgc, imsl = view(img, proplist...)
    props = Dict{Symbol,Any}()
    for (k,v) in proplist
        props[k] = v
    end
    lblsl = ImageSlice2d(label, props)
    imgc.c.mouse.motion = (path,x,y) -> updatexylabel(imgc.handles[:pointerlabel], imgc, slice2!(lblsl, imsl.zindex, imsl.tindex), x, y)
    imgc, imsl
end


# Display a new image in an old ImageCanvas, preserving properties
function view{A<:AbstractArray}(imgc::ImageCanvas, img::A; proplist...)
    # Convert keyword list to dictionary
    props = Dict{Symbol,Any}()
    sizehint(props, length(proplist))
    for (k,v) in proplist
        props[k] = v
    end
    # Extract relevant information from the image and properties
    img2 = ImageSlice2d(img, props)
    w = width(img2)
    h = height(img2)
    allocate_surface!(imgc, w, h)
    create_callbacks(imgc, img2)
    rerender(imgc, img2)
    resize(imgc, img2)
    Tk.configure(imgc.c)
    imgc, img2
end

# Display an image in a Canvas. Do not create controls.
function view{A<:AbstractArray}(c::Canvas, img::A; proplist...)
    # Convert keyword list to dictionary
    props = Dict{Symbol,Any}()
    sizehint(props, length(proplist))
    for (k,v) in proplist
        props[k] = v
    end
    # Extract relevant information from the image and properties
    img2 = ImageSlice2d(img, props)
    imgc = ImageCanvas(cairo_format(img), props)
    imgc.c = c
    w = width(img2)
    h = height(img2)
    allocate_surface!(imgc, w, h)
    create_callbacks(imgc, img2)
    rerender(imgc, img2)
    resize(imgc, img2)
    Tk.configure(imgc.c)
    imgc, img2
end

function canvasgrid(ny, nx; w = 800, h = 600, pad=0, name="ImageView")
    win = Toplevel(name, w, h)
    frame = Frame(win)
    grid(frame, 1, 1, sticky="nsew")
    grid_rowconfigure(win, 1, weight=1)
    grid_columnconfigure(win, 1, weight=1)
    c = Array(Canvas, ny, nx)
    for j = 1:nx
        for i = 1:ny
            c1 = Canvas(frame, w/nx, h/ny)
            grid(c1, i, j, sticky="nsew", padx=pad, pady=pad)
            c[i,j] = c1
        end
    end
    for j = 1:nx
        grid_columnconfigure(frame, j, weight=1)
    end
    for i = 1:ny
        grid_rowconfigure(frame, i, weight=1)
    end
    c
end

function annotate!(imgc::ImageCanvas, img2::ImageSlice2d, ann; anchored::Bool=true)
    len = annotate_nodraw!(imgc, img2, ann; anchored = anchored)
    redraw(imgc)
    len
end

immutable AnnotationHandle{T}
    ann::T
    hash::Uint
end

function annotate_nodraw!(imgc::ImageCanvas, img2::ImageSlice2d, ann; anchored::Bool=true)
    local newann
    if anchored
        newann = AnchoredAnnotation((_)->imgc.canvasbb, (_)->img2.zoombb, ann)
    else
        newann = FloatingAnnotation((_)->imgc.canvasbb, ann)
    end
    h = hash(newann)
    imgc.annotations[h] = newann
    AnnotationHandle(newann, h)
end

function validate_annotations!(imgc::ImageCanvas)
    state = imgc.navigationstate
    for (h,ann) in imgc.annotations
        setvalid!(ann, state.z, state.t)
    end
end    

function delete!(imgc::ImageCanvas, h::AnnotationHandle)
    delete!(imgc.annotations, h.hash)
    redraw(imgc)
end

function empty!(imgc::ImageCanvas)
    empty!(imgc.annotations)
    redraw(imgc)
end

function create_callbacks(imgc, img2)
    c = canvas(imgc)
    # Set up the drawing callbacks
    c.draw = x -> resize(imgc, img2)
    # Bind mouse clicks to zoom
    c.mouse.button1press = (c, x, y) -> rubberband_start(c, x, y, (c, bb) -> zoombb(imgc, img2, bb))
    bind(c, "<Double-Button-1>", (path,x,y)->zoom_reset(imgc, img2))
    # Bind mousewheel events to zoom
    bindwheel(c, "Control", (path,delta,x,y)->zoomwheel(imgc,img2,int(delta),int(x),int(y)), "%x %y")
    # Bind keys to zoom
    win = Tk.toplevel(c)
    bind(win, "<Control-Up>", path->zoomwheel(imgc,img2,-1,pointerxy(win)...))
    bind(win, "<Control-Down>", path->zoomwheel(imgc,img2,1,pointerxy(win)...))
    # Bind mousewheel events to pan
    bindwheel(c, "", (path,delta)->panvert(imgc,img2,int(delta)))
    bindwheel(c, "Shift", (path,delta)->panhorz(imgc,img2,int(delta)))
    # Bind arrow keys to pan
    bind(win, "<Up>", path->panvert(imgc,img2,-1))
    bind(win, "<Down>", path->panvert(imgc,img2,1))
    bind(win, "<Left>", path->panhorz(imgc,img2,-1))
    bind(win, "<Right>", path->panhorz(imgc,img2,1))
end

### Callback handling ###
# This takes the already-rendered surface and paints it to the canvas
function redraw(imgc::ImageCanvas)
    r = getgc(imgc.c)
    # Define the path that encloses the image
    bb = imgc.canvasbb
    w, h = size(imgc.surface.data)  # the image width, height
    save(r)
    reset_clip(r)
    reset_transform(r)
    wbb = width(bb)
    hbb = height(bb)
    rectangle(r, bb.xmin, bb.ymin, wbb, hbb)
    # In cases of transparency, paint the background color
    if imgc.surfaceformat == Cairo.FORMAT_ARGB32 && !is(imgc.background, nothing)
        if isa(imgc.background, CairoPattern)
            set_source(r, imgc.background)
        else
            set_source(r, convert(RGB, imgc.background))
        end
        fill_preserve(r)
    end
    # Paint the image with appropriate antialiasing settings
    Cairo.translate(r, (1-imgc.flipx)*bb.xmin + imgc.flipx*bb.xmax,
                       (1-imgc.flipy)*bb.ymin + imgc.flipy*bb.ymax)
    Cairo.scale(r, (1-2imgc.flipx)*wbb/w, (1-2imgc.flipy)*hbb/h)
    set_source_surface(r, imgc.surface, 0, 0)
    p = get_source(r)
    if wbb > w && hbb > h
        # The canvas is bigger than the image region, show nearest pixel
        Cairo.pattern_set_filter(p, Cairo.FILTER_NEAREST)
    else
        # Fewer pixels in canvas than in image, antialias
        Cairo.pattern_set_filter(p, Cairo.FILTER_GOOD)
    end
    fill(r)
    restore(r)
    # Render any annotations
    for (h,ann) in imgc.annotations
        draw(imgc.c, ann)
    end
    reveal(imgc.c)
    Tk.update()
end

# Used for both window resize and zoom events
function resize(imgc::ImageCanvas, img2::ImageSlice2d)
    w, h = size(imgc.surface.data)
    setbb!(imgc, w, h)
    set_coords(imgc, img2.zoombb)
    r = getgc(imgc.c)
    if !is(imgc.aspect_x_per_y, nothing)
        fill(r, imgc.perimeter)
    end
    redraw(imgc)
end

function updatexylabel(xypos, imgc, img2, x, y)
    xu,yu = device_to_user(getgc(imgc.c), x, y)
    # Image-coordinates
    xi,yi = ifloor(1+xu), ifloor(1+yu)

    if isinside(imgc.canvasbb, x, y)
        # Slice-coordinates (different from above when zoom is active.)
        xs,ys = ifloor(1+xu-xmin(img2)), ifloor(1+yu-ymin(img2))
        val = img2.imslice["x", xs, "y", ys]
        set_value(xypos, "$xi, $yi: $val")
    else
        set_value(xypos, "$xi, $yi")
    end
end

# Navigation in z and t
function reslice(imgc::ImageCanvas, img2::ImageSlice2d, state::NavigationState)
    slice2!(img2, state.z, state.t)
    for (h,ann) in imgc.annotations
        setvalid!(ann, state.z, state.t)
    end
    rerender(imgc, img2)
    redraw(imgc)
end

function reslicet(imgc::ImageCanvas, img2::ImageSlice2d, ctrls::NavigationControls, state::NavigationState, delta::Int)
    t = state.t + 2*(delta>0) - 1
    if 1 <= t <= state.tmax
        state.t = t
        Navigation.updatet(ctrls, state)
        reslice(imgc, img2, state)
    end
end

function reslicez(imgc::ImageCanvas, img2::ImageSlice2d, ctrls::NavigationControls, state::NavigationState, delta::Int)
    z = state.z + 2*(delta>0) - 1
    if 1 <= z <= state.zmax
        state.z = z
        Navigation.updatez(ctrls, state)
        reslice(imgc, img2, state)
    end
end

function zoomwheel(imgc::ImageCanvas, img2::ImageSlice2d, delta, x, y)
    if !isinside(imgc.canvasbb, x, y)
        return
    end
    r = getgc(imgc.c)
    xu, yu = device_to_user(r, x, y)
    local xmn
    local xmx
    local ymn
    local ymx
    if delta < 0
        xmn, xmx = centeredclip(xu, width(img2)/2, xrange(img2))
        ymn, ymx = centeredclip(yu, height(img2)/2, yrange(img2))
    else
        xmn, xmx = centeredclip(xu, 2*width(img2), (1,sizex(img2)), xrange(img2))
        ymn, ymx = centeredclip(yu, 2*height(img2), (1,sizey(img2)), yrange(img2))
    end
    zoombb(imgc, img2, BoundingBox(floor(xmn)-1, ceil(xmx), floor(ymn)-1, ceil(ymx)))
end

function zoombb(imgc::ImageCanvas, img2::ImageSlice2d, bb::BoundingBox)
    bb = BoundingBox(floor(bb.xmin), ceil(bb.xmax), floor(bb.ymin), ceil(bb.ymax))
    w = sizex(img2)
    h = sizey(img2)
    bb = bb & BoundingBox(0, w, 0, h)
    w = int(width(bb))
    h = int(height(bb))
    if w > 0 && h > 0
        allocate_surface!(imgc, w, h)
        panzoom(imgc, img2, bb)
        resize(imgc, img2)
    end
end

function zoom_reset(imgc::ImageCanvas, img2::ImageSlice2d)
    w = sizex(img2)
    h = sizey(img2)
    allocate_surface!(imgc, w, h)
    bb = BoundingBox(0, w, 0, h)
    panzoom(imgc, img2, bb)
    resize(imgc, img2)
end

# Used by pan and zoom to change the displayed region
function panzoom(imgc::ImageCanvas, img2::ImageSlice2d, bb::BoundingBox)
    zoom2!(img2, bb)
    rerender(imgc, img2)
end

function set_coords(imgc::ImageCanvas, bb::BoundingBox)
    l, r = bb.xmin, bb.xmax
    if imgc.flipx
        l, r = r, l
    end
    t, b = bb.ymin, bb.ymax
    if imgc.flipy
        t, b = b, t
    end
    bb = imgc.canvasbb
    set_coords(getgc(imgc.c), bb.xmin, bb.ymin, width(bb), height(bb), l, r, t, b)
end

function panvert(imgc::ImageCanvas, img2::ImageSlice2d, delta)
    h = size(imgc.surface.data, 2)
    local dy
    if delta < 0
        dy = -min(ymin(img2)-1, h/10)
    else
        dy = min(sizey(img2)-ymax(img2), h/10)
    end
    dy = round(dy)
    if dy != 0
        bb = img2.zoombb
        bb = BoundingBox(bb.xmin, bb.xmax, bb.ymin+dy, bb.ymax+dy)
        panzoom(imgc, img2, bb)
        set_coords(imgc, bb)
        redraw(imgc)
    end
end

function panhorz(imgc::ImageCanvas, img2::ImageSlice2d, delta)
    w = size(imgc.surface.data, 1)
    local dx
    if delta < 0
        dx = -min(xmin(img2)-1, w/10)
    else
        dx = min(sizex(img2)-xmax(img2), w/10)
    end
    dx = round(dx)
    if dx != 0
        bb = img2.zoombb
        bb = BoundingBox(bb.xmin+dx, bb.xmax+dx, bb.ymin, bb.ymax)
        panzoom(imgc, img2, bb)
        set_coords(imgc, bb)
        redraw(imgc)
    end
end

### Utilities ###
function allocate_surface!(imgc::ImageCanvas, w, h)
    buf = Array(Uint32, w, h)
    imgc.surface = CairoImageSurface(buf, imgc.surfaceformat, flipxy = false)
    if imgc.transpose
        imgc.renderbuf = Array(Uint32, h, w)
    end
end

# Convert the raw image data to the Uint32 buffer that Cairo paints
function rerender(imgc::ImageCanvas, img2::ImageSlice2d)
    if imgc.transpose
        imgc.render!(imgc.renderbuf, img2.imslice)
        Base.transpose!(imgc.surface.data, imgc.renderbuf)
    else
        imgc.render!(imgc.surface.data, img2.imslice)
    end
end

function redraw(imgc::ImageCanvas, img2::ImageSlice2d)
    rerender(imgc, img2)
    redraw(imgc)
end

# Fill the entire canvas with a color
function fill(r::GraphicsContext, col::ColorValue)
    rgb = convert(RGB, col)
    save(r)
    reset_clip(r)
    reset_transform(r)
    set_source_rgb(r, rgb.r, rgb.g, rgb.b)
    paint(r)
    restore(r)
end

# Create a checkerboard pattern (for use with transparency)
function checker(checkersize::Int; light = 0xffb0b0b0, dark = 0xff404040)
    buf = Array(Uint32, 2checkersize, 2checkersize)
    fill!(buf, light)
    buf[1:checkersize,checkersize+1:2checkersize] = dark
    buf[checkersize+1:2checkersize,1:checkersize] = dark
    s = CairoImageSurface(buf, Cairo.FORMAT_ARGB32)
    checkerboard = CairoPattern(s)
    pattern_set_filter(checkerboard, Cairo.FILTER_NEAREST)
    pattern_set_extend(checkerboard, Cairo.EXTEND_REPEAT)
    checkerboard
end

# r is the aspect ratio, i.e. aspect_x_per_y
function rendersize(w::Integer, h::Integer, r)
    ww = w
    wh = h
    if !is(r, nothing)
        if r > 1
            ww = iround(w*r)
        else
            wh = iround(h/r)
        end
    end
    ww, wh
end

# Create a range of width w centered on x, subject to contraints
# lim and cur are (min,max) tuples
function centeredclip(x, w, lim, cur = lim)
    w = min(w, lim[2]-lim[1])
    f = (x-cur[1])/(cur[2]-cur[1])  # fraction into the range
    xmin = x-f*w                    # preserve the fraction upon resize
    if xmin < lim[1]
        return lim[1], lim[1]+w
    end
    xmax = xmin+w
    if xmax > lim[2]
        return lim[2]-w, lim[2]
    end
    xmin, xmax
end

function resetfirst!(s::SubArray)
    newfirst = 1
    pstride = 1
    for j = 1:length(s.indexes)
        newfirst += (first(s.indexes[j])-1)*pstride
        pstride *= size(s.parent, j)
    end
    s.first_index = newfirst
    s
end

function cairo_format(img::AbstractArray)
    format = Cairo.FORMAT_RGB24
    cs = colorspace(img)
    if cs == "ARGB" || cs == "ARGB32" || cs == "RGBA" || cs == "GrayAlpha"
        format = Cairo.FORMAT_ARGB32
    end
    format
end

function scalebarsize(imsl::ImageSlice2d, width, height)
    indx = findin([imsl.xdim,imsl.ydim], coords_spatial(imsl.imslice))
    ps = pixelspacing(imsl.imslice)
    w = width/ps[indx[1]]/imsl.dims[imsl.xdim]
    h = height/ps[indx[2]]/imsl.dims[imsl.ydim]
    w, h
end

AnnotationScalebarFixed{T}(width::T, height::T, imsl::ImageSlice2d, centerx::Real, centery::Real, color::ColorValue = RGB(1,1,1)) =
    AnnotationScalebarFixed{T}(width, height, (wp,hp) -> scalebarsize(imsl,wp,hp), float64(centerx), float64(centery), color)

scalebar(imgc::ImageCanvas, imsl::ImageSlice2d, length; x = 0.8, y = 0.1, color = RGB(1,1,1)) = annotate!(imgc, imsl, AnnotationScalebarFixed(length/1, length/10, (width,height)->scalebarsize(imsl, width, height), x, y, color), anchored=false)

# Exporting figures

function write_to_png(imgc::ImageCanvas, filename)
    ctx = copy(imgc.c.backcc, imgc.canvasbb)
    Cairo.write_to_png(ctx.surface, filename)
end
