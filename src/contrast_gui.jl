using Gtk.GConstants.GtkAlign: GTK_ALIGN_START, GTK_ALIGN_END, GTK_ALIGN_FILL

function contrast_gui(enabled::Signal{Bool}, hist::Signal, clim::Signal)
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
    cgui = contrast_gui_layout(smin, smax, rng)
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
            rng = linspace(thismin, thismax, 255)
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
        if getproperty(cgui["window"], :visible, Bool) # protects against window destruction
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

function contrast_gui_layout(smin::Signal, smax::Signal, rng)
    win = Window("Contrast") |> (g = Grid())
    slmax = slider(rng; signal=smax)
    slmin = slider(rng; signal=smin)
    for sl in (slmax, slmin)
        setproperty!(sl, :draw_value, false)
    end
    g[1,1] = widget(slmax)
    g[1,3] = widget(slmin)
    cnvs = canvas(UserUnit)
    g[1,2] = widget(cnvs)
    setproperty!(cnvs, :expand, true)
    emax_w = Entry(; width_chars=5, hexpand=false, halign=GTK_ALIGN_END, valign=GTK_ALIGN_START)
    emin_w = Entry(; width_chars=5, hexpand=false, halign=GTK_ALIGN_END, valign=GTK_ALIGN_END)
    g[2,1] = emax_w
    g[2,3] = emin_w
    # By not specifying the range on the textbox, we let the user
    # enter something out-of-range, which can be handy in some
    # circumstances.
    emax = textbox(eltype(smax); widget=emax_w, signal=smax) # , range=rng)
    emin = textbox(eltype(smin); widget=emin_w, signal=smin) #, range=rng)

    showall(win)
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
