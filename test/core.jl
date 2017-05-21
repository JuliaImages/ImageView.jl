using GtkReactive, AxisArrays, ImageView
using ImageView: sliceinds
using Base.Test

@testset "CLim" begin
    cl = Signal(CLim(0.0, 0.8))
    push!(cl, CLim(0, 1))
    Reactive.run_till_now()
    @test value(cl) === CLim{Float64}(0, 1)

    # default contrast setting with a homogenous image
    imgdict = imshow(zeros(3, 3))
    @test value(imgdict["clim"]) == CLim(0.0,1.0)
end

@testset "sliceinds" begin
    A = rand(3,3,3)
    @test @inferred(sliceinds(A, (1:3, 1:3), Axis{3}(1))) === (1:3, 1:3, 1)
    @test @inferred(sliceinds(A, (1:3, 1:3), Axis{2}(1))) === (1:3, 1, 1:3)
    @test @inferred(sliceinds(A, (1:3, 1:3), Axis{1}(1))) === (1, 1:3, 1:3)
    @test_throws TypeError sliceinds(A, (1:3, 1:3), Axis{1}(1), Axis{2}(1))
    @test_throws BoundsError sliceinds(A, (1:3, 1:3), Axis{3}(1), Axis{2}(1))
    @test_throws BoundsError sliceinds(A, (1:3, 1:3), Axis{2}(1), Axis{2}(1))

    B = AxisArray(A, :X, :Y, :Z)
    @test @inferred(sliceinds(B, (1:3, 1:3), Axis{:Z}(1))) === (1:3, 1:3, 1)
    @test @inferred(sliceinds(B, (1:3, 1:3), Axis{:Y}(1))) === (1:3, 1, 1:3)
    @test @inferred(sliceinds(B, (1:3, 1:3), Axis{:X}(1))) === (1, 1:3, 1:3)
    @test_throws MethodError sliceinds(B, (1:3, 1:3), Axis{:X}(1), Axis{:Y}(1))
    @test_throws MethodError sliceinds(B, (1:3, 1:3), Axis{:Z}(1), Axis{:Y}(1))
    @test_throws MethodError sliceinds(B, (1:3, 1:3), Axis{:Y}(1), Axis{:Y}(1))

    A = rand(3,3,3,3)
    zr = ZoomRegion(indices(A)[1:2])
    @test_throws TypeError sliceinds(A, (1:3, 1:3), Axis{3}(1))
    @test @inferred(sliceinds(A, (1:3, 1:3), Axis{3}(1), Axis{4}(1))) === (1:3, 1:3, 1, 1)
    @test @inferred(sliceinds(A, (1:3, 1:3), Axis{2}(1), Axis{4}(1))) === (1:3, 1, 1:3, 1)
    @test @inferred(sliceinds(A, (1:3, 1:3), Axis{1}(1), Axis{3}(1))) === (1, 1:3, 1, 1:3)
    @test_throws BoundsError sliceinds(A, (1:3, 1:3), Axis{2}(1), Axis{2}(1))

    B = AxisArray(A, :W, :X, :Y, :Z)
    @test @inferred(sliceinds(B, (1:3, 1:3), Axis{:Y}(1), Axis{:Z}(1))) === (1:3, 1:3, 1, 1)
    @test @inferred(sliceinds(B, (1:3, 1:3), Axis{:Z}(1), Axis{:Y}(1))) === (1:3, 1:3, 1, 1)
    @test @inferred(sliceinds(B, (1:3, 1:3), Axis{:X}(1), Axis{:Z}(1))) === (1:3, 1, 1:3, 1)
    @test @inferred(sliceinds(B, (1:3, 1:3), Axis{:X}(1), Axis{:W}(1))) === (1, 1, 1:3, 1:3)
    @test_throws BoundsError sliceinds(B, (1:3, 1:3), Axis{:Y}(1), Axis{:Y}(1))
end

@testset "SliceData" begin
    A = reshape(1:9, 3, 3)
    zr, sd = roi(indices(A), (1,2))
    v = @inferred(slice2d(A, value(zr), sd))
    @test v == A
    zr, sd = roi(indices(A), (2,1))
    v = @inferred(slice2d(A, value(zr), sd))
    @test v == A'

    A = reshape(1:27, 3, 3, 3)
    for (slicedims, target) in (((1, 2), view(A, :, :, 1)),
                                ((1, 3), view(A, :, 1, :)),
                                ((2, 3), view(A, 1, :, :)),
                                ((2, 1), view(A, :, :, 1)'),
                                ((3, 1), view(A, :, 1, :)'),
                                ((3, 2), view(A, 1, :, :)'))
        zr, sd = roi(indices(A), slicedims)
        v = @inferred(slice2d(A, value(zr), sd))
        @test v == target
    end

    A = reshape(1:81, 3, 3, 3, 3)
    for (slicedims, target) in (((1, 2), view(A, :, :, 1, 1)),
                                ((1, 3), view(A, :, 1, :, 1)),
                                ((2, 3), view(A, 1, :, :, 1)),
                                ((2, 4), view(A, 1, :, 1, :)),
                                ((3, 4), view(A, 1, 1, :, :)),
                                ((1, 4), view(A, :, 1, 1, :)),
                                ((2, 1), view(A, :, :, 1, 1)'),
                                ((3, 1), view(A, :, 1, :, 1)'),
                                ((3, 2), view(A, 1, :, :, 1)'),
                                ((4, 2), view(A, 1, :, 1, :)'),
                                ((4, 3), view(A, 1, 1, :, :)'),
                                ((4, 1), view(A, :, 1, 1, :)'))
        zr, sd = roi(indices(A), slicedims)
        v = @inferred(slice2d(A, value(zr), sd))
        @test v == target
    end

    B = AxisArray(A, :x, :y, :z, :time)
    for (slicedims, target) in (((:x, :y), view(B, :, :, 1, 1)),
                                ((:x, :z), view(B, :, 1, :, 1)),
                                ((:y, :z), view(B, 1, :, :, 1)),
                                ((:y, :time), view(B, 1, :, 1, :)),
                                ((:z, :time), view(B, 1, 1, :, :)),
                                ((:x, :time), view(B, :, 1, 1, :)),
                                ((:y, :x), view(B, :, :, 1, 1)'),
                                ((:z, :x), view(B, :, 1, :, 1)'),
                                ((:z, :y), view(B, 1, :, :, 1)'),
                                ((:time, :y), view(B, 1, :, 1, :)'),
                                ((:time, :z), view(B, 1, 1, :, :)'),
                                ((:time, :x), view(B, :, 1, 1, :)'))
        zr, sd = roi(axes(B), slicedims)
        v = @inferred(slice2d(B, value(zr), sd))
        @test v == target
    end
end

@testset "Canvas size" begin
    @test ImageView.canvas_size((1000,1000), (300, 200)) == (300, 200)
    @test ImageView.canvas_size((1000,1000), (8, 5)) == (160, 100)
    @test ImageView.canvas_size((1000,1000), (3000, 2000)) == (1000, 667)
end

nothing
