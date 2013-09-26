# Once this stabilizes, migrate to a Base.Graphics layer? Only if that supports text, which seems unlikely.
using Color
using Base.Graphics

abstract AbstractAnnotation

# Use this type when you want your annotation to be linked to particular data-coordinates
# (for example, to highlight a particular data point)
# devicebb(data) returns a BoundingBox in device coordinates, userbb(data) returns one in user coordinates.
# It's up to the draw() function to decide how to exploit these (most commonly, with set_coords())
type AnchoredAnnotation{T} <: AbstractAnnotation
    devicebb::Function
    userbb::Function
    data::T
    valid::Bool
end
AnchoredAnnotation{T}(devicebb::Function, userbb::Function, data::T) = AnchoredAnnotation{T}(devicebb, userbb, data, true)

# Use this type when you want your annotation to appear at a specific point on the screen, regardless
# of zoom/resize state (e.g., a scale bar)
type FloatingAnnotation{T} <: AbstractAnnotation
    devicebb::Function
    data::T
end
# FloatingAnnotation{T}(devicebb::Function, data::T) = AnchoredAnnotation{T}(devicebb, data)

type AnnotationText
    x::Float64
    y::Float64
    z::Float64
    t::Float64
    string::String
    color::ColorValue
    fontdesc::ASCIIString
    angle::Float64
    halign::ASCIIString
    valign::ASCIIString
    markup::Bool
end

function AnnotationText(x::Real, y::Real, str::String;
                        z = NaN, t = NaN,
                        color = RGB(0,0,0), angle = 0.0, fontfamily = "sans", fontsize = 10,
                        fontoptions = "",  halign = "center", valign = "center", markup = false)
    AnnotationText(float64(x), float64(y), float64(z), float64(t), str, color, string(fontfamily, " ", fontoptions, " ", fontsize),
                   float64(angle), halign, valign, markup)
end

type AnnotationScalebarFixed{T}
    width::T   # Probably has units
    height::T
    getsize::Function   # syntax w,h = getsize(width,height)
    centerx::Float64
    centery::Float64
    color::ColorValue
end
AnnotationScalebar{T}(width::T, height::T, getsize::Function, centerx::Real, centery::Real, color::ColorValue = RGB(1,1,1)) = AnnotationScalebar{T}(width, height, getsize, float64(centerx), float64(centery), color)

function setvalid!(ann::AnchoredAnnotation{AnnotationText}, z, t)
    dat = ann.data
    ann.valid = (isnan(dat.z) || round(dat.z) == z) &&
        (isnan(dat.t) || round(dat.t) == t)
end

function setvalid!(ann::AnchoredAnnotation, z, t)
    ann.valid = true
end

function setvalid!(ann::FloatingAnnotation, z, t)
end

function draw(c::Canvas, ann::AnchoredAnnotation{AnnotationText})
    if ann.valid
        ctx = getgc(c)
        save(ctx)
        data = ann.data
        set_coords(ctx, ann.devicebb(data), ann.userbb(data))
        set_source(ctx, data.color)
        Cairo.set_font_face(ctx, data.fontdesc)
        Cairo.text(ctx, data.x-0.5, data.y-0.5, data.string, halign = data.halign, valign = data.valign,
                angle = data.angle, markup = data.markup)
        restore(ctx)
    end
end

function draw{T}(c::Canvas, ann::FloatingAnnotation{AnnotationScalebarFixed{T}})
    ctx = getgc(c)
    save(ctx)
    data = ann.data
    set_coords(ctx, ann.devicebb(data), BoundingBox(0,1,0,1))
    set_source(ctx, data.color)
    w, h = data.getsize(data.width, data.height)
    bb = BoundingBox(-w/2+data.centerx, w/2+data.centerx, -h/2+data.centery, h/2+data.centery)
    rectangle(ctx, bb)
    fill(ctx)
    restore(ctx)
end
