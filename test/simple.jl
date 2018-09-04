using ImageView
using Images, OffsetArrays, Reactive
using Test

@testset "Simple grayscale" begin
    imshow_now(rand(Gray{N0f8}, 10, 10))
    # clamping checks
    imshow_now(rand(UInt8, 10, 10))  # most/all pixels should be white
    A = randn(10, 10)
    imshow_now(A)
    A[2,2] = NaN
    A[3,3] = -Inf
    A[4,4] = Inf
    imshow_now(A)

    # default contrast setting with a homogenous image
    imgdict = imshow_now(zeros(3, 3))
    @test value(imgdict["clim"]) == ImageView.CLim(0.0,1.0)
end

@testset "Simple RGB" begin
    imshow_now(rand(RGB{N0f8}, 10, 10))
    # clamping checks
    A = randn(3, 10, 10)
    imshow_now(colorview(RGB, A))
    A[1,2,2] = NaN
    A[1,3,3] = -Inf
    A[1,4,4] = Inf
    imshow_now(colorview(RGB, A))

end

@testset "Non-1 indices" begin
    A = OffsetArray(rand(11, 10), -5:5, 0:9)
    ret = imshow_now(A)
end
