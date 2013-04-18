# Display images so they fill a window

# TkRenderer adapted from Winston's tk.jl
import Tk
import Cairo

const Surface = Cairo.CairoSurface
const Canvas = Tk.Canvas

# Create a window of a given size and initialize a canvas
function TkRenderer(name, w, h)
    win = Tk.Window(name, w, h)
    c = Canvas(win)
    Tk.pack(c, {:expand => true, :fill => "both"})  # support resize
    # We'll set redraw later
    c
end

# Type for storing settings related to image display
type ImagePanelSettings
    zoombb::BoundingBox      # selected region, in user coordinates
    renderbb::BoundingBox    # drawing region, in device coordinates
    aspect_constrained::Bool          # true if next parameter is to be used
    aspect_x_per_y::Float64           # relative scaling of the two axes
    background                        # nothing, RGB color, or checkerboard pattern
    perimeter                         # RGB color
end

# Here w and h are the image width and height, in pixels
# pixel_spacing is a 2-vector giving the spacing (in arbitrary units) of pixels along x and y
function initialize_canvas(c::Canvas, w, h, props::Dict)
    ps = get(props, "pixel_spacing", nothing)
    background = get(props, "background", nothing)
    perimeter = get(props, "perimeter", RGB(1,1,1))
    aspect_constrained = !is(ps, nothing)
    aspect_x_per_y = 1.0
    if aspect_constrained
        if length(ps) != 2
            error("pixel_spacing must be two-dimensional")
        end
        aspect_x_per_y = ps[2]/ps[1]
    end
    zoombb = BoundingBox(0, w, 0, h)
    renderbb = BoundingBox(0, width(c), 0, height(c))
    ip = ImagePanelSettings(zoombb, renderbb, aspect_constrained, aspect_x_per_y, background, perimeter)
    if aspect_constrained
        placeimage!(ip, c)
    end
    r = getgc(c)
    set_coords(r, renderbb, zoombb)
    if aspect_constrained
        fill_canvas(r, perimeter)
    end
    ip
end

# Size the rendered region
function placeimage!(ip::ImagePanelSettings, c::Canvas)
    if ip.aspect_constrained
        wc = Tk.width(c)
        hc = Tk.height(c)
        wi = width(ip.zoombb)
        hi = height(ip.zoombb)
        sx = min(wc/wi, ip.aspect_x_per_y*hc/hi)
        sy = sx/ip.aspect_x_per_y
        wdraw = sx*wi
        hdraw = sy*hi
        xmin = (wc-wdraw)/2
        ymin = (hc-hdraw)/2
        ip.renderbb = BoundingBox(xmin, xmin+wdraw, ymin, ymin+hdraw)
    else
        ip.renderbb = BoundingBox(0, width(c), 0, height(c))
    end
    ip
end

function fill_canvas(r::GraphicsContext, col::ColorValue)
    rgb = convert(RGB, col)
    save(r)
    Cairo.reset_clip(r)
    set_source_rgb(r, rgb.r, rgb.g, rgb.b)
    paint(r)
    restore(r)
end

function fill_background(r::GraphicsContext, ip::ImagePanelSettings, col::ColorValue)
    rgb = convert(RGB, col)
    set_source_rgb(r, rgb.r, rgb.g, rgb.b)
    rectangle(r, zoombb.xmin, zoombb.ymin, width(zoombb), height(zoombb))
    fill(r)
end

function set_coords(r::GraphicsContext, renderbb::BoundingBox, zoombb::BoundingBox)
    Base.Graphics.set_coords(r, renderbb.xmin, renderbb.ymin, width(renderbb), height(renderbb),
               zoombb.xmin, zoombb.xmax, zoombb.ymin, zoombb.ymax)
end

# Create a window that "views" an in-memory buffer
# This does no transposition, that should be handled by the caller (or see copyt! below)
type WindowImage
    c::Canvas
    surf::Surface
    buf::Array{Uint32,2}
    ip::ImagePanelSettings

    function WindowImage(buf::Array{Uint32,2}, props::Dict = Dict(), format::Integer = Cairo.CAIRO_FORMAT_RGB24, title::String = "Julia")
        w, h = size(buf)    # note it's in [x,y] order, not [row,col] order!
        c = TkRenderer(title, w, h)
        surf = Cairo.CairoImageSurface(buf, format, w, h)
        ip = initialize_canvas(c, w, h, props)
        obj = new(c, surf, buf, ip)
        # Set up the resize callback
        rcb = Tk.tcl_callback((path) -> resize(obj))
        Tk.tcl_eval("bind $(c.c.path) <Configure> {$rcb}")
        # Set up redraw function
        c.redraw = function (_)
            redraw(obj)
        end
        redraw(obj)
    end
end

function redraw(wb::WindowImage)
    r = getgc(wb.c)
    if !is(wb.ip.background, nothing)
        hastransparency = Cairo.image_surface_get_format(wb.surf) == Cairo.CAIRO_FORMAT_ARGB32
        if hastransparency
            fill_background(r, wb.ip, wb.ip.background)
        end
    end
    rectangle(r, wb.ip.zoombb.xmin, wb.ip.zoombb.ymin, width(wb.ip.zoombb), height(wb.ip.zoombb))
    Cairo.set_source_surface(r, wb.surf, 0, 0)
    p = Cairo.get_source(r)
    if width(wb.ip.renderbb) > width(wb.ip.zoombb) && height(wb.ip.renderbb) > height(wb.ip.zoombb)
        Cairo.pattern_set_filter(p, Cairo.CAIRO_FILTER_NEAREST)
    else
        Cairo.pattern_set_filter(p, Cairo.CAIRO_FILTER_GOOD)
    end
    fill(r)
#     Tk.reveal(wb.c)
#     Tk.tcl_doevent()
    wb
end

show(io::IO, wb::WindowImage) = print(io, "WindowImage with buffer size ", Base.dims2string(size(wb.buf)))

function resize(wb::WindowImage)
    Tk.configure(wb.c)
    _resize(wb)
end

function _resize(wb::WindowImage)
    placeimage!(wb.ip, wb.c)
    r = getgc(wb.c)
    set_coords(r, wb.ip.renderbb, wb.ip.zoombb)
    if wb.ip.aspect_constrained
        fill_canvas(r, wb.ip.perimeter)
    end
    redraw(wb)
end

function zoom(wb::WindowImage, zoombb::BoundingBox)
    wb.ip.zoombb = zoombb
    _resize(wb)
end

function zoom_reset(wb::WindowImage)
    wb.ip.zoombb = BoundingBox(0, size(wb.buf,1), 0, size(wb.buf,2))
    _resize(wb)
end

# # If you write new data to the buffer (e.g., using copy!), refresh the display
# function update(wb::WindowImage)
#     Cairo.image(Tk.getgc(wb.c), wb.surf, 0, 0, Cairo.width(wb.surf), Cairo.height(wb.surf))
#     wb.c.redraw(wb.c)
# end

copy!(wb::WindowImage, data::Array{Uint32,2}) = copy!(wb.buf, data)
fill!(wb::WindowImage, val::Uint32) = fill!(wb.buf, val)

# Copy-with-transpose
function copyt!(buf::Array{Uint32,2}, data::Array{Uint32,2})
    h, w = size(data)
    if size(buf,1) != w || size(buf,2) != h
        error("Size mismatch")
    end
    for j = 1:w, i = 1:h
        buf[j,i] = data[i,j]
    end
    buf
end

#### A demo  ####
# w = 400
# h = 200
# buf = zeros(Uint32,w,h)
# fill!(buf,0x00FF0000)  # red
# wb = WindowImage(buf)
#
# sleep(1)
#
# for val = 0x00000000:0x000000FF
#     fill!(wb, val)
#     update(wb)
# end



# Now add some code to display Images
# display(r::Cairo.CairoRenderer, img::AbstractArray, x, y, w, h)
#     buf = cairoRGB(img)
#     imw, imh = size(buf)
#     surf = Cairo.CairoImageSurface(buf, format, imw, imh)
#     Cairo.image(r, surf, x, y, w, h)
#     r.on_close()
# end
# display(r::Cairo.CairoRenderer, img::AbstractArray) = display(r, img, r.lowerleft[1], r.lowerleft[2], 

# display in a previous window
function display(wb::WindowImage, img::AbstractArray, scalei::Images.ScaleInfo)
    cairoRGB(wb.buf, img, scalei)
    redraw(wb)
end
display(wb::WindowImage, img::AbstractArray) = display(wb, img, scaleinfo(Uint8, img))

# display in a new window
function display(img::AbstractArray, props::Dict = Dict(), scalei::Images.ScaleInfo = Images.scaleinfo(Uint8, img))
    buf, format = cairoRGB(img, scalei)
    WindowImage(buf, props, format)
end

# Changing display properties
function aspect(wb::WindowImage, ps)
    aspect_constrained = !is(ps, nothing)
    aspect_x_per_y = 1.0
    if aspect_constrained
        if length(ps) != 2
            error("pixel_spacing must be two-dimensional")
        end
        aspect_x_per_y = ps[2]/ps[1]
    end
    wb.ip.aspect_constrained = aspect_constrained
    wb.ip.aspect_x_per_y = aspect_x_per_y
    _resize(wb)
end

function background(wb::WindowImage, bkg)
    wb.ip.background = bkg
    redraw(wb)
end

function perimeter(wb::WindowImage, p)
    wb.ip.perimeter = p
    redraw(wb)
end

## Efficient conversions to RGB24 or ARGB32
function cairoRGB(img::Union(StridedArray,Images.AbstractImageDirect), scalei::Images.ScaleInfo)
    w, h = Images.widthheight(img)
    buf = Array(Uint32, w, h)
    format = cairoRGB(buf, img, scalei)
    buf, format
end

function cairoRGB(buf::Array{Uint32,2}, img::Union(StridedArray,Images.AbstractImageDirect), scalei::Images.ScaleInfo)
    Images.assert2d(img)
    cs = Images.colorspace(img)
    xfirst = Images.isxfirst(img)
    firstindex, spsz, spstride, csz, cstride = Images.iterate_spatial(img)
    isz, jsz = spsz
    istride, jstride = spstride
    A = Images.parent(img)
    if xfirst
        w, h = isz, jsz
    else
        w, h = jsz, isz
    end
    if size(buf, 1) != w || size(buf, 2) != h
        error("Output buffer is of the wrong size")
    end
    # Check to see whether we can do a direct copy
    if eltype(img) <: Union(Uint32, Int32)
        if cs == "RGB24"
            if xfirst
                copy!(buf, img.data)
            else
                copyt!(buf, img.data)
            end
            return Cairo.CAIRO_FORMAT_RGB24
        elseif cs == "ARGB32"
            if xfirst
                copy!(buf, img.data)
            else
                copyt!(buf, img.data)
            end
            return Cairo.CAIRO_FORMAT_ARGB32
        end
    end
    local format
    if cstride == 0
        if cs == "Gray"
            if xfirst
                # Note: can't use a single linear index for RHS, because this might be a subarray
                l = 1
                for j = 1:jsz
                    k = firstindex + (j-1)*jstride
                    for i = 0:istride:(isz-1)*istride
                        gr = scale(scalei, A[k+i])
                        buf[l] = rgb24(gr, gr, gr)
                        l += 1
                    end
                end
            else
                for j = 1:jsz
                    k = firstindex + (j-1)*jstride
                    for i = 1:isz
                        gr = scale(scalei, A[k+(i-1)*istride])
                        buf[j,i] = rgb24(gr, gr, gr)
                    end
                end
            end
            format = Cairo.CAIRO_FORMAT_RGB24
        else
            error("colorspace ", cs, " not yet supported")
        end
    else
        if cs == "RGB"
            if xfirst
                l = 1
                for j = 1:jsz
                    k = firstindex + (j-1)*jstride
                    for i = 0:istride:(isz-1)*istride
                        ki = k+i
                        buf[l] = rgb24(scalei, A[ki], A[ki+cstride], A[ki+2cstride])
                        l += 1
                    end
                end
            else
                for j = 1:jsz
                    k = firstindex + (j-1)*jstride
                    for i = 1:isz
                        ki = k+(i-1)*istride
                        buf[j,i] = rgb24(scalei, A[ki], A[ki+cstride], A[ki+2cstride])
                    end
                end
            end
            format = Cairo.CAIRO_FORMAT_RGB24
        elseif cs == "ARGB"
            if xfirst
                l = 1
                for j = 1:jsz
                    k = firstindex + (j-1)*jstride
                    for i = 0:istride:(isz-1)*istride
                        ki = k+i
                        buf[l] = argb32(scalei,A[ki],A[ki+cstride],A[ki+2cstride],A[ki+3cstride])
                        l += 1
                    end
                end
            else
                for j = 1:jsz
                    k = firstindex + (j-1)*jstride
                    for i = 1:isz
                        ki = k+(i-1)*istride
                        buf[j,i] = argb32(scalei,A[ki],A[ki+cstride],A[ki+2cstride],A[ki+3cstride])
                    end
                end
            end
            format = Cairo.CAIRO_FORMAT_ARGB32
        elseif cs == "RGBA"
            if xfirst
                l = 1
                for j = 1:jsz
                    k = firstindex + (j-1)*jstride
                    for i = 0:istride:(isz-1)*istride
                        ki = k+i
                        buf[l] = argb32(scalei,A[ki+3cstride],A[ki],A[ki+cstride],A[ki+2cstride])
                        l += 1
                    end
                end
            else
                for j = 1:jsz
                    k = firstindex + (j-1)*jstride
                    for i = 1:isz
                        ki = k+(i-1)*istride
                        buf[j,i] = argb32(scalei,A[ki+3cstride],A[ki],A[ki+cstride],A[ki+2cstride])
                    end
                end
            end
            format = Cairo.CAIRO_FORMAT_ARGB32
        else
            error("colorspace ", cs, " not yet supported")
        end
    end
    format
end

rgb24(r::Uint8, g::Uint8, b::Uint8) = convert(Uint32,r)<<16 + convert(Uint32,g)<<8 + convert(Uint32,b)

argb32(a::Uint8, r::Uint8, g::Uint8, b::Uint8) = convert(Uint32,a)<<24 + convert(Uint32,r)<<16 + convert(Uint32,g)<<8 + convert(Uint32,b)

rgb24{T}(scalei::Images.ScaleInfo{Uint8}, r::T, g::T, b::T) = convert(Uint32,Images.scale(scalei,r))<<16 + convert(Uint32,Images.scale(scalei,g))<<8 + convert(Uint32,Images.scale(scalei,b))

argb32{T}(scalei::Images.ScaleInfo{Uint8}, a::T, r::T, g::T, b::T) = convert(Uint32,Images.scale(scalei,a))<<24 + convert(Uint32,Images.scale(scalei,r))<<16 + convert(Uint32,Images.scale(scalei,g))<<8 + convert(Uint32,Images.scale(scalei,b))



## External-viewer interface
function imshow(img, range)
    if ndims(img) == 2 
        # only makes sense for gray scale images
        img = imadjustintensity(img, range)
    end
    tmp::String = "tmp.ppm"
    imwrite(img, tmp)
    cmd = `$imshow_cmd $tmp`
    spawn(cmd)
end

imshow(img) = imshow(img, [])

# 'illustrates' fourier transform
ftshow{T}(A::Array{T,2}) = imshow(log(1+abs(fftshift(A))),[])

