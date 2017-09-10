function canvasgrid(ny, nx; w = 800, h = 600, name="ImageView", kwargs...)
    Base.depwarn("canvasgrid(ny, nx; kwargs...) is deprecated, use canvasgrid((ny, nx)) instead. Note the returned value has changed.", :canvasgrid)
    g, frames, canvases = canvasgrid((ny, nx))
    win = Window(name, w, h)
    window_wrefs[win] = nothing
    signal_connect(win, :destroy) do widget
        delete!(window_wrefs, widget)
    end
    push!(win, g)
    showall(win)
    canvases
end

function pixelspacing_dep(img, kwargs)
    for (k,v) in kwargs
        if k == :pixelspacing
            Base.depwarn("pixelspacing keyword is deprecated, use an AxisArray to encode pixel spacing", :imshow)
        end
        return AxisArray(img, default_names(img), (v...))
    end
    img
end

default_names(img::AbstractMatrix) = (:y, :x)
default_names(img::AbstractArray{T,3}) where {T} = (:y, :x, :z)
default_names(img::AbstractArray{T,4}) where {T} = (:y, :x, :z, :time)
