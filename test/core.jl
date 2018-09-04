using GtkReactive, Images, ImageView
using ImageView: sliceinds
using Test
import AxisArrays
using AxisArrays: Axis

@testset "CLim" begin
    cl = Signal(CLim(0.0, 0.8))
    push!(cl, CLim(0, 1))
    Reactive.run_till_now()
    @test value(cl) === CLim{Float64}(0, 1)

    cmin = RGB(0.2,0.4,0.1)
    cmax = RGB(1.0,0.8,0.95)
    smm = scaleminmax(RGB{N0f8}, cmin, cmax)
    @test @inferred(smm(cmin)) == RGB(0,0,0)
    @test @inferred(smm(cmax)) == RGB(1,1,1)
    @test @inferred(smm((cmin+1.00001*cmax)/2)) == RGB{N0f8}(0.5,0.5,0.5)
end

@testset "NaN and Inf" begin
    # Grayscale
    A = collect(reshape(range(-0.1, stop=1.1, length=25), (5, 5)))
    A[2,2] = NaN
    A[3,3] = -Inf
    A[4,4] = Inf

    target = Gray{N0f8}[
        0   0.0625  0.375   0.6875  1;
        0   0       0.4375  0.75    1;
        0   0.1875  0       0.8125  1;
        0   0.25    0.5625  1       1;
        0   0.3125  0.625   0.9375  1
    ]

    img = Signal(A)
    clim = Signal(CLim(0.1, 0.9))
    enabled, histsigs, imgcsig = ImageView.prep_contrast(img, clim)
    imgc = value(imgcsig)
    @test eltype(imgc) == Gray{N0f8}
    @test imgc == target

    img = Signal(Gray.(A))
    clim = Signal(CLim(0.1, 0.9))
    enabled, histsigs, imgcsig = ImageView.prep_contrast(img, clim)
    imgc = value(imgcsig)
    @test eltype(imgc) == Gray{N0f8}
    @test imgc == target

    # RGB
    Ar = collect(reshape(range(-0.1, stop=1.1, length=3*25), (3, 5, 5)))
    Arc = copy(Ar)
    Ar[1,2,2] = NaN
    Ar[2,3,3] = -Inf
    Ar[3,4,4] = Inf
    target = colorview(RGB, N0f8.((clamp.(Arc, 0.1, 0.9) .- 0.1)./0.8))
    c = target[2,2]
    target[2,2] = RGB{N0f8}(0, green(c), blue(c))
    c = target[3,3]
    target[3,3] = RGB{N0f8}(red(c), 0, blue(c))
    c = target[4,4]
    target[4,4] = RGB{N0f8}(red(c), green(c), 1)

    img = Signal(colorview(RGB, Ar))
    cmin, cmax = RGB(0.1,0.1,0.1), RGB(0.9, 0.9, 0.9)
    clim = Signal(CLim(cmin, cmax))
    enabled, histsigs, imgcsig = ImageView.prep_contrast(img, clim)
    imgc = value(imgcsig)
    @test eltype(imgc) == RGB{N0f8}
    @test imgc == target
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
    zr = ZoomRegion(axes(A)[1:2])
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
    zr, sd = roi(axes(A), (1,2))
    v = @inferred(slice2d(A, value(zr), sd))
    @test v == A
    zr, sd = roi(axes(A), (2,1))
    v = @inferred(slice2d(A, value(zr), sd))
    @test v == A'

    A = reshape(1:27, 3, 3, 3)
    for (slicedims, target) in (((1, 2), view(A, :, :, 1)),
                                ((1, 3), view(A, :, 1, :)),
                                ((2, 3), view(A, 1, :, :)),
                                ((2, 1), view(A, :, :, 1)'),
                                ((3, 1), view(A, :, 1, :)'),
                                ((3, 2), view(A, 1, :, :)'))
        zr, sd = roi(axes(A), slicedims)
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
        zr, sd = roi(axes(A), slicedims)
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
        zr, sd = roi(AxisArrays.axes(B), slicedims)
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
