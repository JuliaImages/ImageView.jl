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
end
AnchoredAnnotation(devicebb::Function, userbb::Function, data::AbstractAnnotation) =
    AnchoredAnnotation{typeof(data)}(devicebb, userbb, data)

# Use this type when you want your annotation to appear at a specific point on the screen, regardless
# of zoom/resize state (e.g., a scale bar)
type FloatingAnnotation{T} <: AbstractAnnotation
    devicebb::Function
    data::T
end

type AnnotationText
    x::Float64
    y::Float64
    string::String
    color::ColorValue
    fontdesc::ASCIIString
    angle::Float64
    halign::ASCIIString
    valign::ASCIIString
    markup::Bool
end

function AnnotationText(x::Real, y::Real, str::String;
                        color = RGB(0,0,0), angle = 0.0, fontfamily = "sans", fontsize = 10,
                        fontoptions = "",  halign = "center", valign = "center", markup = false)
    AnnotationText(float64(x), float64(y), str, color, string(fontfamily, " ", fontoptions, " ", fontsize),
                   float64(angle), halign, valign, markup)
end

function draw(c::Canvas, ann::AnchoredAnnotation{AnnotationText})
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
