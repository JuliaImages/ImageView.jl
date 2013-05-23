module ImageContrast

# using Base.Graphics
using Cairo
using Tk
using Winston
using Images

type ContrastSettings
    min
    max
end

# The callback should have the syntax:
#    callback(cs)
function contrastgui{T}(img::AbstractArray{T}, cs::ContrastSettings, callback::Function)
    win = Toplevel("Adjust contrast", 500, 300, true)
    contrastgui(win, img, cs, callback)
end

function contrastgui{T}(win::Tk.TTk_Container, img::AbstractArray{T}, cs::ContrastSettings, callback::Function)
    fwin = Frame(win)
    w = width(win.w)
    h = height(win.w)
    pack(fwin, expand=true, fill="both")
    
    chist = Canvas(fwin, 2w/3, h)
    grid(chist, 1, 1, sticky="nsew", padx=5)
    fctrls = Frame(fwin)
    grid(fctrls, 1, 2)
    grid_columnconfigure(fwin, 1, weight=1)
    grid_rowconfigure(fwin, 1, weight=1)
    
    fminmax = Frame(fctrls)
    emin = Entry(fminmax, width=10)
    emax = Entry(fminmax, width=10)
    formlayout(emin, "Min:")
    formlayout(emax, "Max:")
    grid(fminmax, 1, 1:2, sticky="nw")
    
    zoom = Button(fctrls, "Zoom")
    full = Button(fctrls, "Full range")
    grid(zoom, 2, 1, sticky="sw", padx=5)
    grid(full, 2, 2, sticky="se")
    
    immin = min(img)
    immax = max(img)
    if is(cs.min, nothing)
        cs.min = immin
    end
    if is(cs.max, nothing)
        cs.max = immax
    end
    cs.min = convert(T, cs.min)
    cs.max = convert(T, cs.max)
    set_value(emin, string(cs.min))
    set_value(emax, string(cs.max))
    
    # Prepare the histogram
    nbins = iceil(min(sqrt(length(img)), 200))
    p = prepare_histogram(img, nbins, immin, immax)
    
    function rerender()
        pcopy = deepcopy(p)
        println(cs)
#         showcomponents(p)
#         ylim = getattr(p, "yrange")
#         @show ylim
        bb = Winston.limits(p.content1)
        ylim = [bb.ymin, bb.ymax]
        @show ylim
        add(pcopy, Curve([cs.min,cs.min],ylim,"color","blue"))
        add(pcopy, Curve([cs.max,cs.max],ylim,"color","red"))
        Winston.display(chist, pcopy)
        reveal(chist)
        callback(cs)
        Tk.update()
    end
    function replaceimage(newimg, minval = min(newimg), maxval = max(newimg))
        p = prepare_histogram(newimg, nbins, minval, maxval)
        rerender()
    end
    bind(emin, "<Return>", path -> setmin(emin, cs, rerender))
    bind(emax, "<Return>", path -> setmax(emax, cs, rerender))
    rerender()
    replaceimage
end

function prepare_histogram(img, nbins, immin, immax)
    e = immin:(immax-immin)/(nbins-1):immax*(1+1e-6)
    e, counts = hist(img[:], e)
    counts += 1   # because of log scaling
    x, y = stairs(e, counts)
    p = FramedPlot()
    setattr(p, "ylog", true)
    add(p, FillBetween(x, ones(length(x)), x, y, "color", "black"))
    setattr(p.frame, "tickdir", 1)
#     showcomponents(p)
    p
end

function showcomponents(p)
    for obj in p.content1.components
        println("Here's a new content1 component: ", obj)
    end
    for obj in p.content2.components
        println("Here's a new content2 component: ", obj)
    end
end

function stairs(xin::AbstractVector, yin::Vector)
    nbins = length(yin)
    if length(xin) != nbins+1
        error("Pass edges for x, and bin values for y")
    end
    xout = zeros(0)
    yout = zeros(0)
    sizehint(xout, 2nbins)
    sizehint(yout, 2nbins)
    push!(xout, xin[1])
    for i = 2:nbins
        xtmp = xin[i]
        push!(xout, xtmp)
        push!(xout, xtmp)
    end
    push!(xout, xin[end])
    for i = 1:nbins
        ytmp = yin[i]
        push!(yout, ytmp)
        push!(yout, ytmp)
    end
    xout, yout
end

function setmin(w::Tk.Tk_Entry, cs::ContrastSettings, render::Function)
    try
        val = float64(get_value(w))
        cs.min = val
        render()
    catch
        set_value(w, string(cs.min))
    end
    @show cs
end

function setmax(w::Tk.Tk_Entry, cs::ContrastSettings, render::Function)
    try
        val = float64(get_value(w))
        cs.max = val
        render()
    catch
        set_value(w, string(cs.max))
    end
end

end
