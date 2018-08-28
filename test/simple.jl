import ImageView
using Images, OffsetArrays, Reactive
using Base.Test

# Grayscale
ImageView.imshow(rand(Gray{N0f8}, 10, 10))
# clamping checks
ImageView.imshow(rand(UInt8, 10, 10))  # most/all pixels should be white
A = randn(10, 10)
ImageView.imshow(A)
A[2,2] = NaN
A[3,3] = -Inf
A[4,4] = Inf
ImageView.imshow(A)

# default contrast setting with a homogenous image
imgdict = ImageView.imshow(zeros(3, 3))
@test value(imgdict["clim"]) == ImageView.CLim(0.0,1.0)

# RGB
ImageView.imshow(rand(RGB{N0f8}, 10, 10))
# clamping checks
A = randn(3, 10, 10)
ImageView.imshow(colorview(RGB, A))
A[1,2,2] = NaN
A[1,3,3] = -Inf
A[1,4,4] = Inf
ImageView.imshow(colorview(RGB, A))

# Non-1 indices
A = OffsetArray(rand(11, 10), -5:5, 0:9)
ret = ImageView.imshow(A)
