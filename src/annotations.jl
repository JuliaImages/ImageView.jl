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

type AnnotationPoints{R<:Union(Real,(Real,Real)),T<:Union(R,Vector{R},Matrix{R})}
    pts::T
    z::Float64
    t::Float64
    size::Float64
    shape::Char
    color::ColorValue
    linewidth::Float64
    linecolor::ColorValue
end

AnnotationPoints{R<:(Real,Real)}(xys::Vector{R}=(Float64,Float64)[]; z = NaN, t = NaN, size=10.0, shape::Char='x', color = RGB(1,1,1), linewidth=1.0, linecolor=color) = AnnotationPoints{R,Vector{R}}(xys, z, t, float(size), shape, Color.color(color), float(linewidth), Color.color(linecolor))

AnnotationPoints{R<:Real}(xys::Matrix{R}; z = NaN, t = NaN, size=10.0, shape::Char='x', color = RGB(1,1,1), linewidth=1.0, linecolor=color) = AnnotationPoints{R,Matrix{R}}(xys, z, t, float(size), shape, Color.color(color), float(linewidth), Color.color(linecolor))

AnnotationPoint(xy::(Real,Real); z = NaN, t = NaN, size=10.0, shape::Char='x', color = RGB(1,1,1), linewidth=1.0, linecolor=color) = AnnotationPoints{Float64,(Float64,Float64)}((float64(xy[1]), float64(xy[2])), z, t, float(size), shape, Color.color(color), float(linewidth), Color.color(linecolor))

AnnotationPoint(x::Real, y::Real; args...) = AnnotationPoint((float64(x), float64(y)); args...)


type AnnotationLines{R<:Real,T<:Union((R,R,R,R),Vector{(R,R,R,R)},Matrix{R})}
    lines::T
    z::Float64
    t::Float64
    linecolor::ColorValue
    linewidth::Float64
end

AnnotationLines{R<:Real}(lines::Vector{(R,R,R,R)}=((Float64,Float64,Float64,Float64))[]; z = NaN, t = NaN, color=RGB(1,1,1), linewidth=1.0) = AnnotationLines{R,Vector{(R,R,R,R)}}(lines, z, t, color, linewidth)

AnnotationLines{R<:Real}(lines::Matrix{R}; z = NaN, t = NaN, color=RGB(1,1,1), linewidth=1.0) = AnnotationLines{R,Matrix{R}}(lines, z, t, color, linewidth)

AnnotationLine{R<:Real}(line::(R,R,R,R); z = NaN, t = NaN, color=RGB(1,1,1), linewidth=1.0) = AnnotationLines{R,(R,R,R,R)}(line, z, t, color, linewidth)
#AnnotationLine(pt1::(Real,Real), pt2::(Real,Real); args...) = AnnotationLines((pt1..., pt2...); args...)
AnnotationLine(x1::Real, y1::Real, x2::Real, y2::Real; args...) = AnnotationLine((float64(x1),float64(y1),float64(x2),float64(y2)); args...)


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

function draw{R,T}(c::Canvas, ann::AnchoredAnnotation{AnnotationPoints{R,T}})
    if ann.valid
        ctx = getgc(c)
        save(ctx)
        data = ann.data
        set_line_width(ctx, data.linewidth)
        set_source(ctx, data.linecolor)
        draw_pts(ctx, data.pts, data.size, data.shape, data.color, data.linecolor)
        restore(ctx)
    end
end

draw_pts(ctx::CairoContext, pt::NTuple{2}, args...) = draw_pt(ctx, pt, args...)

function draw_pts{R<:(Real,Real)}(ctx::CairoContext, pts::Vector{R}, args...)
    for pt in pts
        draw_pt(ctx, pt, args...)
    end
end

function draw_pts(ctx::CairoContext, pts::Matrix, args...)
    @assert size(pts,1) == 2
    for i in size(pts,2)
        pt = pts[:,i]
        draw_pt(ctx, pt, args...)
    end
end


function draw_pt(ctx::CairoContext, pt, sz::Float64, shape::Char, color::ColorValue, linecolor::ColorValue)
    x::Float64,y::Float64 = pt
    hsz = sz/2

    if shape == '.' | shape == 'o'
        move_to(ctx, x, y)
        circle(ctx, x, y, sz)
        if shape == '.'
            set_source(ctx, color)
            fill(ctx)
            set_source(ctx, linecolor)
        end
    elseif (shape == 'x') | (shape == '*') | (shape == '+')
        if (shape == 'x') | (shape == '*')
            move_to(ctx, x-hsz, y-hsz)
            line_to(ctx, x+hsz, y+hsz)
            move_to(ctx, x-hsz, y+hsz)
            line_to(ctx, x+hsz, y-hsz)
        end
        if (shape == '+') | (shape == '*')
            move_to(ctx, x-hsz, y)
            line_to(ctx, x+hsz, y)
            move_to(ctx, x, y-hsz)
            line_to(ctx, x, y+hsz)
        end
    end

    stroke(ctx)
end

function draw{R,T}(c::Canvas, ann::AnchoredAnnotation{AnnotationLines{R,T}})
    if ann.valid
        ctx = getgc(c)
        save(ctx)
        data = ann.data
        set_line_width(ctx, data.linewidth)
        set_source(ctx, data.linecolor)
        draw_lines(ctx, data.lines)
        restore(ctx)
    end
end

draw_lines(ctx::CairoContext, line::NTuple{4}) = draw_line(ctx, line)

function draw_lines{R<:Real}(ctx::CairoContext, lines::Vector{(R,R,R,R)})
    for line in lines
        draw_line(ctx, line)
    end
end

function draw_lines(ctx::CairoContext, lines::Matrix)
    @assert size(lines,1) == 4
    for i in size(lines,2)
        pt = lines[:,i]
        draw_line(ctx, pt)
    end
end

function draw_line(ctx::CairoContext, line)
    x1,y1,x2,y2 = line
    move_to(ctx, x1,y1)
    line_to(ctx, x2,y2)
    stroke(ctx)
end
