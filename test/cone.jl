## Objects that are not AbstractArrays can also be displayed with `imshow`.
# This file demonstrates and tests the interface that such objects must satisfy.

module ConeModule

using FixedPointNumbers, Colors, ImageCore, Cairo, Reactive, ImageView

export Cone

# A cone in 3d
immutable Cone{C<:Colorant}
    sz3::Tuple{Int,Int,Int}
    center2::Tuple{Int,Int}
    colort::Vector{C}

    function (::Type{Cone{C}}){C}(sz3, colort)
        center2 = ((sz3[1]+1)÷2, (sz3[2]+1)÷2)
        new{C}(sz3, center2, colort)
    end
end
Cone{C<:Colorant}(sz3::Tuple{Int,Int,Int}, colort::Vector{C}) = Cone{C}(sz3, colort)

## These define the interface that an object needs to support in order
## to be displayable with imshow

# What you actually need to implement is `indices(c)`, but we can do that here via `size`
Base.size(c::Cone) = (c.sz3..., length(c.colort))
Base.view(c::Cone, x, y, z, t) = ConeView(c, map(normalize_inds, indices(c), (x, y, z, t)))

# You must support `view` and three functions (`size`, `pixelspacing`,
# and `copy!`) on whatever kind of object `view` returns.  How you do
# that is up to you; here is one example.
immutable ConeView{C<:Colorant,I}
    cone::Cone{C}
    indices::I
end

Base.size(cv::ConeView) = mapvec(length, cv.indices...)

function ImageCore.pixelspacing(cv::ConeView)
    filterby(x->isa(x, AbstractVector), cv.indices[1:3], (1, 1, 5))
end

# copy! is what gets called when it's time to paint pixels on the canvas.
# You could alternatively provide `getindex`-style functionality.
function Base.copy!(canvas::Cairo.CairoContext, cv::ConeView)
    img = similar(Array{RGB{N0f8}}, indices(cv))
    fill!(img, zero(eltype(img)))
    c = cv.cone
    for (idest, isrc) in zip(CartesianRange(indices(img)), CartesianRange(cv.indices))
        x, y, z, t = isrc.I
        img[idest] =
            ((x-c.center2[1])^2 + (y-c.center2[2])^2 <= (c.sz3[3] - z + 1)^2)*c.colort[t]
    end
    copy!(canvas, img)
end

## Helper functions
# You don't need to implement these specific functions: they're here
# only to support the specific implementations above.
normalize_inds(ref, ind) = ind
normalize_inds(ref, ::Colon) = ref

function filterby(f, test, ret)
    fbtail = filterby(f, test[2:end], ret[2:end])
    f(test[1]) ? (ret[1], fbtail...) : fbtail
end
filterby(f, ::Tuple{}, ::Tuple{}) = ()

# map f over the indices, keeping only the AbstractVectors
mapvec(f, i::Real, I...) = mapvec(f, I...)
mapvec(f, i, I...) = (f(i), mapvec(f, I...)...)
mapvec(f) = ()

end

using Colors, FixedPointNumbers, GtkReactive, ImageView

## Create an object and visualize it
c = ConeModule.Cone((201, 301, 31), rand(RGB{N0f8}, 60))
imshow(c; name="Cone 1,2")

# Slice along axes 1 and t rather than 3 and t
imshow(c, axes=(2,3), name="Cone 2,3")
