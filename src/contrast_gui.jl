using Gtk.GConstants.GtkAlign: GTK_ALIGN_START, GTK_ALIGN_END, GTK_ALIGN_FILL

function change_red(col::CLim{T}, chan::CLim{T2}) where {T<:AbstractRGB, T2<:GrayLike}
    cmin = T(chan.min, green(col.min), blue(col.min))
    cmax = T(chan.max, green(col.max), blue(col.max))
    return CLim(cmin, cmax)
end
function change_green(col::CLim{T}, chan::CLim{T2}) where {T<:AbstractRGB, T2<:GrayLike}
    cmin = T(red(col.min), chan.min, blue(col.min))
    cmax = T(red(col.max), chan.max, blue(col.max))
    return CLim(cmin, cmax)
end
function change_blue(col::CLim{T}, chan::CLim{T2}) where {T<:AbstractRGB, T2<:GrayLike}
    cmin = T(red(col.min), green(col.min), chan.min)
    cmax = T(red(col.max), green(col.max), chan.max)
    return CLim(cmin, cmax)
end
change_red(col::Signal, chan::CLim) = change_red(value(col), chan)
change_green(col::Signal, chan::CLim) = change_green(value(col), chan)
change_blue(col::Signal, chan::CLim) = change_blue(value(col), chan)

function contrast_gui(enabled::Signal{Bool}, hists::Vector, clim::Signal{CLim{T}}) where {T<:AbstractRGB}
    @assert length(hists) == 3 #one signal per color channel
    chanlims = channel_clims(value(clim))
    rsig = Signal(chanlims[1])
    gsig = Signal(chanlims[2])
    bsig = Signal(chanlims[3])
    #make sure that changes to individual channels update the color clim signal and vice versa
    bindmap!(clim, x->change_red(clim, x), rsig, x->channel_clim(red, x); initial = false)
    bindmap!(clim, x->change_green(clim, x), gsig, x->channel_clim(green, x); initial = false)
    bindmap!(clim, x->change_blue(clim, x), bsig, x->channel_clim(blue, x); initial = false)
    names = ["Red Contrast"; "Green Contrast"; "Blue Contrast"]
    csigs = [rsig; gsig; bsig]
    cguis = []
    for i=1:length(hists)
        push!(cguis, contrast_gui(enabled, hists[i], csigs[i]; wname = names[i]))
    end
    return cguis
end

contrast_gui(enabled, hist::Vector, clim) = contrast_gui(enabled, hist[1], clim)

function contrast_gui(enabled::Signal{Bool}, hist::Signal, clim::Signal; wname="Contrast")
    vhist, vclim = value(hist), value(clim)
    T = eltype(vclim)
    Δ = T <: Integer ? T(1) : eps(T)
    rng = vhist.edges[1]
    cmin, cmax = vclim.min, vclim.max
    if !(cmin < cmax)
        cmin, cmax = first(rng), last(rng)
        if !(cmin < cmax)
            cmin, cmax = zero(cmin), one(cmax)
        end
    end
    smin = Signal(convert(eltype(rng), cmin))
    smax = Signal(convert(eltype(rng), cmax))
    cgui = contrast_gui_layout(smin, smax, rng; wname=wname)
    signal_connect(cgui["window"], :destroy) do widget
        push!(enabled, false)
    end
    updateclim = map(smin, smax) do cmin, cmax
        # if min/max is outside the current range, update the sliders
        adj = Gtk.Adjustment(widget(cgui["slider_min"]))
        rmin, rmax = Gtk.G_.lower(adj), Gtk.G_.upper(adj)
        if cmin < rmin || cmax > rmax || cmax-cmin < Δ
            # Also, don't cross the sliders
            bigmax = max(cmin,cmax,rmin,rmax)
            bigmin = min(cmin,cmax,rmin,rmax)
            thismax = min(typemax(T), max(cmin, cmax, rmax))
            thismin = max(typemin(T), min(cmin, cmax, rmin))
            rng = range(thismin, stop=thismax, length=255)
            cminT, cmaxT = T(min(cmin, cmax)), T(max(cmin, cmax))
            if cminT == cmaxT
                cminT = min(cminT, cminT-Δ)
                cmaxT = max(cmaxT, cmaxT+Δ)
            end
            mn, mx = minimum(rng), maximum(rng)
            cmin, cmax = clamp(cminT, mn, mx), clamp(cmaxT, mn, mx)
            push!(cgui["slider_min"], rng, cmin)
            push!(cgui["slider_max"], rng, cmax)
        end
        # Update the image contrast
        push!(clim, CLim(cmin, cmax))
    end
    # TODO: we might want to throttle this?
    redraw = draw(cgui["canvas"], hist) do cnvs, hst
        if get_gtk_property(cgui["window"], :visible, Bool) # protects against window destruction
            rng, cl = hst.edges[1], value(clim)
            mn, mx = minimum(rng), maximum(rng)
            push!(cgui["slider_min"], rng, clamp(cl.min, mn, mx))
            push!(cgui["slider_max"], rng, clamp(cl.max, mn, mx))
            drawhist(cnvs, hst)
        end
    end
    GtkReactive.gc_preserve(cgui["window"], (cgui, redraw, updateclim))
    cgui
end

function contrast_gui_layout(smin::Signal, smax::Signal, rng; wname="Contrast")
    win = Window(wname) |> (g = Grid())
    slmax = slider(rng; signal=smax)
    slmin = slider(rng; signal=smin)
    for sl in (slmax, slmin)
        set_gtk_property!(sl, :draw_value, false)
    end
    g[1,1] = widget(slmax)
    g[1,3] = widget(slmin)
    cnvs = canvas(UserUnit)
    g[1,2] = widget(cnvs)
    set_gtk_property!(cnvs, :expand, true)
    emax_w = Entry(; width_chars=5, hexpand=false, halign=GTK_ALIGN_END, valign=GTK_ALIGN_START)
    emin_w = Entry(; width_chars=5, hexpand=false, halign=GTK_ALIGN_END, valign=GTK_ALIGN_END)
    g[2,1] = emax_w
    g[2,3] = emin_w
    # By not specifying the range on the textbox, we let the user
    # enter something out-of-range, which can be handy in some
    # circumstances.
    emax = textbox(eltype(smax); widget=emax_w, signal=smax) # , range=rng)
    emin = textbox(eltype(smin); widget=emin_w, signal=smin) #, range=rng)

    Gtk.showall(win)
    Dict("window"=>win, "canvas"=>cnvs, "slider_min"=>slmin, "slider_max"=>slmax, "textbox_min"=>emin, "textbox_max"=>emax)
end

# We could use one of the plotting toolkits, but most are pretty slow
# to load and/or produce the first plot. So let's just do it manually.
@guarded function drawhist(canvas, hist)
    ctx = getgc(canvas)
    fill!(canvas, colorant"white")
    edges, counts = hist.edges[1], hist.weights
    xmin, xmax = first(edges), last(edges)
    cmax = maximum(counts)
    if cmax <= 0 || !(xmin < xmax)
        return nothing
    end
    set_coordinates(ctx, BoundingBox(xmin, xmax, log10(cmax+1), 0))
    set_source(ctx, colorant"black")
    move_to(ctx, xmax, 0)
    line_to(ctx, xmin, 0)
    for (i, c) in enumerate(counts)
        line_to(ctx, edges[i], log10(c+1))
        line_to(ctx, edges[i+1], log10(c+1))
    end
    line_to(ctx, xmax, 0)
    fill(ctx)
    nothing
end
