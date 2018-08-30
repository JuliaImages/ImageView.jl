## Objects that are not AbstractArrays can also be displayed with `imshow`.
# This file demonstrates and tests the interface that such objects must satisfy.

module ConeModule

using FixedPointNumbers, Colors, ImageCore, Cairo, Reactive, ImageView
using Base: tail

export Cone

# A cone in 3d
struct Cone{C<:Colorant}
    sz3::Tuple{Int,Int,Int}
    center2::Tuple{Int,Int}
    colort::Vector{C}

    function Cone{C}(sz3, colort) where C
        center2 = ((sz3[1]+1)÷2, (sz3[2]+1)÷2)
        new{C}(sz3, center2, colort)
    end
end
Cone(sz3::Tuple{Int,Int,Int}, colort::Vector{C}) where {C<:Colorant} = Cone{C}(sz3, colort)

## These define the interface that an object needs to support in order
## to be displayable with imshow

Base.eltype(::Type{Cone{C}}) where {C} = C

# What you actually need to implement is `axes(c)`, but we can do that here via `size`
Base.size(c::Cone) = (c.sz3..., length(c.colort))

# c[x, y, z, t]
function Base.getindex(c::Cone, y::Real, x::Real, z::Real, t::Real)
    ((x-c.center2[2])^2 + (y-c.center2[1])^2 <= (c.sz3[3] - z + 1)^2)*c.colort[t]
end
function Base.getindex(c::Cone, y, x, z, t)
    # indexing with vectors or colons
    inds = map(normalize_inds, axes(c), (y, x, z, t))
    sz = map(length, filtervec(inds, inds))
    yn, xn, zn, tn = inds
    ps = filtervec((1.0, 1.0, 5.0), (yn, xn, zn))  # to get the pixelspacing correct
    out = Array{eltype(c)}(undef, sz)
    k = 0
    for ti in tn, zi in zn, xi in xn, yi in yn
        out[k+=1] = c[yi,xi,zi,ti]
    end
    SpacedArray(out, ps)
end

## Helper functions
# You don't need to implement these specific functions: they're here
# only to support the specific implementations above.

# An array with custom pixelspacing. If you don't need to customize
# ps, then you could just use a plain Array in the getindex method
# above.
struct SpacedArray{T,N} <: AbstractArray{T,N}
    a::Array{T,N}
    ps::NTuple{N,Float64}
end
ImageCore.pixelspacing(A::SpacedArray) = A.ps
@inline Base.getindex(A::SpacedArray, inds...) = A.a[inds...]
@inline Base.setindex!(A::SpacedArray, val, inds...) = A.a[inds...] = val
Base.size(A::SpacedArray) = size(A.a)

# Replace colons with explicit range vectors
normalize_inds(ref, ind) = ind
normalize_inds(ref, ::Colon) = ref

# Choose elements from the first tuple based on vector entries in the second
@inline filtervec(t1, t2::Tuple{AbstractVector,Vararg{Any}}) = (t1[1], filtervec(tail(t1), tail(t2))...)
@inline filtervec(t1, t2::Tuple{Real,Vararg{Any}}) = filtervec(tail(t1), tail(t2))
filtervec(::Tuple{}, ::Tuple{}) = ()

end

using Colors, FixedPointNumbers, GtkReactive, ImageView

## Create an object and visualize it
c = ConeModule.Cone((201, 301, 31), rand(RGB{N0f8}, 60))
imshow_now(c; name="Cone 1,2")

# Slice along axes 1 and t rather than 3 and t
imshow_now(c, axes=(2,3), name="Cone 2,3")
