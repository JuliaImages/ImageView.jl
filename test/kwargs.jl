using ImageView
using TestImages
using Test

@testset "contrast with kwargs" begin
    # test for the fix in #228
    # Uses 2D images to verify the `axes` and `flipy` kwargs work
    # with a passed CLim argument
    mri = testimage("mri")
    vmin = Float32(minimum(mri))
    vmax = Float32(maximum(mri))
    clim = ImageView.CLim(vmin, vmax)

    ImageView.imshow(mri, clim; axes=(1, 2))
    @test true
    ImageView.imshow(mri, clim; axes=(3, 1), flipy=true)
    @test true
    ImageView.imshow(mri, clim; axes=(3, 2), flipy=true)
    @test true
end

@testset "window size with kwargs" begin
    gd = imshow([1 0; 0 1], canvassize=(500,500))
    get(ENV, "CI", nothing) === nothing && @test all(>=(500), size(gd["gui"]["window"]))
end
