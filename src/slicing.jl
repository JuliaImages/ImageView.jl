using Base: Indices, tail, PermutedDimsArrays.PermutedDimsArray

struct SliceData{transpose,N,Axs}
    signals::NTuple{N,Signal{Int}}
    axs::Axs
end

function Base.show(io::IO, sd::SliceData{transpose,N}) where {transpose,N}
    println(io, "SliceData{transpose=$transpose}:")
    for i = 1:N
        println(io, "  ", axisname(sd.axs[i]), ": ", value(sd.signals[i]))
    end
end
axisname(ax::Axis) = axisnames(ax)[1]

"""
    SliceData{transpose::Bool}(signals::NTuple{N,Signal{Int}}, axes::NTuple{N,Axes})

Specify slice information for a (possibly) multidimensional
image. `signals` hold the currently-selected slices for the selected
`axes`, all of which are effectively "orthogonal" to the plane in the
viewer.
"""
SliceData{transpose}(signals::NTuple{N,Signal{Int}}, axs::NTuple{N,Axis}) where {transpose,N} =
    SliceData{transpose,N,typeof(axs)}(signals, axs)
SliceData{transpose}() where {transpose} = SliceData{transpose}((), ())

Base.isempty(sd::SliceData{transpose,N}) where {transpose,N} = N == 0
Base.length(sd::SliceData{transpose,N}) where {transpose,N} = N

"""
    roi(A) -> zr::Signal(ZoomRegion), slicedata::SliceData
    roi(A, dims=(1,2)) -> zr::Signal(ZoomRegion), slicedata::SliceData
    roi(A, (:namey, :namex)) -> zr::Signal(ZoomRegion), slicedata::SliceData

Create the initial "region of interest" for viewing `A`. For
multidimensional objects, optionally select two dimensions (the first
two, by default) for slicing. The outputs `zr` and `slicedata`
describe the within-view and player-controlled axes, respectively.

See also: [`slice2d`](@ref).
"""
roi(A) = roi(A, (1,2))

roi(A, dims) = roi(axes(A), dims)
roi(A, axs::Tuple{Symbol,Symbol}) = roi(AxisArrays.axes(A), axs)

function roi(inds::Indices, dims::Dims{2})
    dims[1] != dims[2] || error("entries in dims must be distinct, got ", dims)
    zr = ZoomRegion(inds[[dims...]])
    sigs, axs = [], []
    for i = 1:length(inds)
        if !(i ∈ dims)
            ind = inds[i]
            push!(sigs, Signal(first(ind)))
            push!(axs, Axis{i}(ind))
        end
    end
    Signal(zr), SliceData{dims[2] < dims[1]}((sigs...,), (axs...,))
end

function roi(axs::NTuple{N,Axis}, axnames::Tuple{Symbol,Symbol}) where N
    axnames[1] != axnames[2] || error("entries in axnames must be distinct, got ", axnames)
    names = axisnames(axs...)
    dims = indexin([axnames...], [names...])
    inds = map(v->axes(v, 1), axisvalues(axs...))
    zr = ZoomRegion(inds[[dims...]])
    sigs, axs = [], []
    for (i, n) in enumerate(names)
        if !(n ∈ axnames)
            ind = inds[i]
            push!(sigs, Signal(first(ind)))
            push!(axs, Axis{n}(ind))
        end
    end
    Signal(zr), SliceData{dims[2] < dims[1]}((sigs...,), (axs...,))
end

"""
    slice2d(A, zr, sd) -> A2

Create a two-dimensional slice `A2` using the current ZoomRegion `zr`
and SliceData `sd`.
"""
function slice2d(img, zr::ZoomRegion, sd::SliceData{false})
    slice2d(img, makeroi(zr, false), makeslices(sd)...)
end
function slice2d(img, zr::ZoomRegion, sd::SliceData{true})
    transposedview(slice2d(img, makeroi(zr, true), makeslices(sd)...))
end

function makeroi(zr::ZoomRegion, transpose::Bool)
    rngs = map(UnitRange{Int}, (zr.currentview.y, zr.currentview.x))
    transpose ? (rngs[2], rngs[1]) : rngs
end

makeslices(sd::SliceData) = makeslices(sd.axs, sd.signals)
makeslices(axs::NTuple{N,Axis}, sigs::NTuple{N,Signal}) where {N} =
    map((ax,s) -> ax(value(s)), axs, sigs)

function slice2d(img::AbstractArray, roi, slices::Axis...)
    inds = sliceinds(img, roi, slices...)
    view(img, inds...)
end
function slice2d(img, roi, slices::Axis...)
    inds = sliceinds(img, roi, slices...)
    img[inds...]
end

# Infer whether we're using positional or named axes. This allows us
# to use positional labels even with AxisArrays.
abstract type TagType end
struct Positional <: TagType end
struct Named <: TagType end

TagType(::Type{Axis{name}}) where {name} = isa(name, Integer) ? Positional() : Named()
TagType(::Type{Axis{name,T}}) where {name,T} = TagType(Axis{name})
TagType(ax::Axis) = TagType(typeof(ax))

@inline tagtype(axs::Axis...) = check_same(map(TagType, axs)...)
@inline check_same(tt1::T, tt2::T, tts...) where {T<:TagType} = check_same(tt2, tts...)
@inline check_same(tt1::T, tts...) where {T<:TagType} = tt1
check_same(tt1::T) where {T<:TagType} = tt1
check_same() = Positional()

@noinline check_same(tt1::TagType, tt2::TagType, tts...) = error("must use either positional or named")

"""
    inds = sliceinds(img, roi, slices...)
    inds = sliceinds(axs, roi, slices...)

Return an indices-tuple `inds` that selects the region-of-interest `roi` at particular `slices`
along orthogonal coordinates. Use `AxisArrays.Axis` to indicate out-of-order axes, either
by dimension number (e.g., `Axis{3}`) or by name (`Axis{:z}`).
If you're using dimension numbers, `slices` must list them in increasing order.

# Examples:
```julia
julia> using AxisArrays: Axis

# Mimic a 4d array
julia> axs = (1:1080, 1:1920, 1:20, 1:1000)
(1:1080, 1:1920, 1:20, 1:1000)

julia> ImageView.sliceinds(axs, (6:10, 1:5), Axis{3}(7), Axis{4}(15))
(6:10, 1:5, 7, 15)

julia> ImageView.sliceinds(axs, (6:10, 1:5), Axis{2}(7), Axis{4}(15))
(6:10, 7, 1:5, 15)

# Mimic a 4d AxisArray
julia> axs = (Axis{:y}(1:1080), Axis{:x}(1:1920), Axis{:z}(1:20), Axis{:t}(1:1000))
(Axis{:y,UnitRange{Int64}}(1:1080), Axis{:x,UnitRange{Int64}}(1:1920), Axis{:z,UnitRange{Int64}}(1:20), Axis{:t,UnitRange{Int64}}(1:1000))

julia> ImageView.sliceinds(axs, (6:10, 1:5), Axis{:t}(15), Axis{:z}(7))   # out-of-order OK
(6:10, 1:5, 7, 15)

julia> ImageView.sliceinds(axs, (6:10, 1:5), Axis{:y}(15), Axis{:z}(7))
(15, 6:10, 7, 1:5)
```
"""
sliceinds(img, zoomranges, slices...) =
    sliceinds_t(tagtype(slices...), img, zoomranges, slices...)
sliceinds_t(::Positional, img, zoomranges, slices...) =
    sliceinds(axes(img), zoomranges, slices...)
sliceinds_t(::Named, img, zoomranges, slices...) =
    sliceinds(AxisArrays.axes(img), zoomranges, slices...)

# Positional
# Here we insist the axes are supplied in increasing order
sliceinds(axs::Tuple{}, zoomranges::Tuple{}) = ()
@inline sliceinds(inds::Indices, zoomranges, slices...) =
    _sliceinds((false,), inds, zoomranges, slices...)  # seed so that d-matching works below

@inline _sliceinds(out, inds::NTuple{N,Any}, ::Tuple{}) where {N} = tail(out)::NTuple{N,Any}
@inline _sliceinds(out, inds, zoomranges) =
    _sliceinds((out..., zoomranges[1]), inds, tail(zoomranges))
@inline _sliceinds(out::NTuple{d,Any}, inds, zoomranges, slice1::Axis{d}, slices...) where {d} =
    _sliceinds((out..., slice1.val), inds, zoomranges, slices...)
@inline _sliceinds(out, inds, zoomranges, slice1::Axis{d}, slices...) where {d} =
    _sliceinds((out..., zoomranges[1]), inds, tail(zoomranges), slice1, slices...)

# Named
# Here we allow any ordering of axes
@inline function sliceinds(axs::NTuple{N,Axis}, zoomranges, slices...) where N
    ind, newzoomranges, newslices = pickaxis((), axs[1], zoomranges, slices...)
    # ind, newzoomranges, newslices = pickaxis(axs[1], zoomranges, slices...)
    (ind, sliceinds(tail(axs), newzoomranges, newslices...)...)
end

@inline pickaxis(out, ax::Axis, zoomranges, slice1::Axis, slices...) =
    _pickaxis(out, AxisArrays.samesym(ax, slice1), ax, zoomranges, slice1, slices...)
@inline _pickaxis(out, ::Val{true}, ax, zoomranges, slice1, slices...) =
    slice1.val, zoomranges, (out..., slices...)
@inline _pickaxis(out, ::Val{false}, ax, zoomranges, slice1, slices...) =
    pickaxis((out..., slice1), ax, zoomranges, slices...)
@inline pickaxis(out, ax::Axis, zoomranges) =
    zoomranges[1], tail(zoomranges), out

# @generated function pickaxis(ax::Axis{name}, zoomranges, slices...) where name
#     idx = findfirst(x->axisnames(x)[1] == name, slices)
#     if idx == 0
#         return quote
#             zoomranges[1], tail(zoomranges), slices
#         end
#     end
#     newslices_exprs = [:(slices[$i]) for i in setdiff(1:length(slices), idx)]
#     quote
#         slices[$idx].val, zoomranges, ($(newslices_exprs...),)
#     end
# end

# For type stability we don't want to use permuteddimsview
transposedview(A::AbstractMatrix) =
    PermutedDimsArray{eltype(A),2,(2,1),(2,1),typeof(A)}(A)

function transposedview(A::AxisArray{T,2}) where T
    axs = AxisArrays.axes(A)
    AxisArray(transposedview(A.data), (axs[2], axs[1]))
end
