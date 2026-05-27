# Legacy string-key access (deprecation shim).
# Translates the pre-0.14 nested-`Dict` API to the new `ImageDisplay` /
# `ImageViewGUI` / `ImageROI` structs. Slated for removal in the next
# breaking release. Each call emits a `Base.depwarn`.

function Base.getindex(d::ImageDisplay, key::AbstractString)
    Base.depwarn(
        "indexing `imshow`'s return value by string is deprecated; use field access. " *
        "Replace `result[\"$key\"]` with `result.$(_legacy_to_field(key))`.",
        :getindex)
    return _legacy_get(d, key)
end
function Base.setindex!(d::ImageDisplay, value, key::AbstractString)
    Base.depwarn(
        "string-key assignment on `imshow`'s return value is deprecated.",
        :setindex!)
    _legacy_set!(d, key, value)
end

function Base.getindex(g::ImageViewGUI, key::AbstractString)
    Base.depwarn(
        "indexing the `ImageViewGUI` by string is deprecated; use field access. " *
        "Replace `gui[\"$key\"]` with `gui.$(_legacy_to_field(key))`.",
        :getindex)
    return _legacy_get(g, key)
end
function Base.setindex!(g::ImageViewGUI, value, key::AbstractString)
    Base.depwarn("string-key assignment on `ImageViewGUI` is deprecated.", :setindex!)
    _legacy_set!(g, key, value)
end

function Base.getindex(r::ImageROI, key::AbstractString)
    Base.depwarn(
        "indexing the `ImageROI` by string is deprecated; use field access. " *
        "Replace `roi[\"$key\"]` with `roi.$(_legacy_to_field(key))`.",
        :getindex)
    return _legacy_get(r, key)
end
function Base.setindex!(r::ImageROI, value, key::AbstractString)
    Base.depwarn("string-key assignment on `ImageROI` is deprecated.", :setindex!)
    _legacy_set!(r, key, value)
end

# Legacy strings → modern field names
_legacy_to_field(key::AbstractString) = replace(key, ' ' => '_')

function _legacy_get(d::ImageDisplay, key::AbstractString)
    key == "gui"         && return getfield(d, :gui)
    key == "roi"         && return getfield(d, :roi)
    key == "clim"        && return getfield(d, :clim)
    key == "annotations" && return getfield(d, :annotations)
    throw(KeyError(key))
end
function _legacy_set!(d::ImageDisplay, key::AbstractString, _)
    throw(ArgumentError("ImageDisplay top-level keys are not settable (got \"$key\")"))
end

function _legacy_get(g::ImageViewGUI, key::AbstractString)
    key == "window"         && return getfield(g, :window)
    key == "vbox"           && return getfield(g, :vbox)
    key == "frame"          && return getfield(g, :frame)
    key == "canvas"         && return getfield(g, :canvas)
    key == "status"         && return getfield(g, :status)
    key == "viewlabel"      && return getfield(g, :viewlabel)
    key == "players"        && return getfield(g, :players)
    key == "hoverinfo"      && return getfield(g, :hoverinfo)
    key == "zoomregion_info" && return getfield(g, :zoomregion_info)
    key == "guidata"        && return getfield(g, :extras)[:guidata]
    # Pre-0.13 callers used the GUI Dict as scratch space for arbitrary keys
    # (e.g. stashing a `zoom_region` observable). Route those through `extras`.
    return getfield(g, :extras)[Symbol(key)]
end
function _legacy_set!(g::ImageViewGUI, key::AbstractString, value)
    key == "hoverinfo"       && (g.hoverinfo = value; return value)
    key == "zoomregion_info" && (g.zoomregion_info = value; return value)
    key == "players"         && (g.players = value; return value)
    getfield(g, :extras)[Symbol(key)] = value
    return value
end

Base.haskey(g::ImageViewGUI, key::AbstractString) =
    _legacy_haskey_known(g, key) || haskey(getfield(g, :extras), Symbol(key))

function _legacy_haskey_known(::ImageViewGUI, key::AbstractString)
    return key in ("window", "vbox", "frame", "canvas", "status", "viewlabel",
                   "players", "hoverinfo", "zoomregion_info", "guidata")
end

function _legacy_get(r::ImageROI, key::AbstractString)
    key == "image roi"        && return getfield(r, :image_roi)
    key == "zoomregion"       && return getfield(r, :zoomregion)
    key == "zoom_rubberband"  && return getfield(r, :zoom_rubberband)
    key == "zoom_scroll"      && return getfield(r, :zoom_scroll)
    key == "pan_scroll"       && return getfield(r, :pan_scroll)
    key == "pan_drag"         && return getfield(r, :pan_drag)
    key == "redraw"           && return getfield(r, :redraw)
    key == "slicedata"        && return getfield(r, :slicedata)
    throw(KeyError(key))
end
function _legacy_set!(r::ImageROI, key::AbstractString, value)
    key == "slicedata" && (r.slicedata = value; return value)
    throw(ArgumentError("cannot assign legacy key \"$key\" on ImageROI"))
end
