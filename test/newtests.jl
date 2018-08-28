using ImageView, TestImages, Colors, FixedPointNumbers, ImageCore, Reactive,
      GtkReactive, AxisArrays, Gtk
using Base.Test

@testset "1d" begin
    img = rand(N0f8, 5)
    guidict = imshow(img)
    win = guidict["gui"]["window"]
    destroy(win)
end

@testset "Aspect ratio" begin
    img = rand(N0f8, 20, 20)
    guidict = imshow(img)
    win, frame = guidict["gui"]["window"], guidict["gui"]["frame"]
    @test isa(frame, Gtk.GtkAspectFrameLeaf)
    zr = guidict["roi"]["zoomregion"]
    Reactive.run_till_now()
    sleep(1.0)  # give compilation a chance to catch up

    @test getproperty(frame, :ratio, Float32) == 1.0
    push!(zr, (1:20, 8:10))  # The first one sometimes gets dropped. Reactive bug?
    Reactive.run_till_now()
    push!(zr, (1:20, 9:10))
    Reactive.run_till_now()
    sleep(1.0)
    @test value(zr).currentview.x == 9..10
    @test getproperty(frame, :ratio, Float32) ≈ 0.1
    push!(zr, (9:10, 1:20))
    Reactive.run_till_now()
    showall(win)
    sleep(0.1)
    @test getproperty(frame, :ratio, Float32) ≈ 10.0

    destroy(win)

    guidict = imshow(img, aspect=:none)
    win, frame = guidict["gui"]["window"], guidict["gui"]["frame"]
    @test isa(frame, Gtk.GtkFrameLeaf)
    destroy(win)
end

# image display
img_n0f8 = rand(N0f8, 3,3)
imsd = imshow(img_n0f8; name="N0f8")
@test getproperty(imsd["gui"]["window"], :title, String) == "N0f8"

img_n0f16 = rand(N0f16, 3,3)
imshow(img_n0f16; name="N0f16")

img_rgb = rand(RGB{N0f8}, 3, 3)
imshow(img_rgb; name="RGB{N0f8}")

img_int = rand(Int, 3,3)
imshow(img_int; name="Int")

img_float16 = rand(Float16, 3,3)
imshow(img_float16; name="Float16")

img_float32 = rand(Float32, 3,3)
img_float32[1,1] = NaN
img_float32[2,1] = Inf
img_float32[3,1] = -5
imshow(img_float32; name="Float32")

img_float64 = rand(Float64, 3,3)
imshow(img_float64; name="Float64")

img_nan = fill(NaN, (3,3))
imshow(img_nan; name="NaN")

img_rgbfloat = rand(RGB{Float32}, 3, 3)
imshow(img_rgbfloat; name="RGB{Float32}")

img = testimage("lighthouse")
hlh = imshow(img, name="Lighthouse")

# a large image
img = testimage("earth")
hbig = imshow(img, name="Earth")
win = hbig["gui"]["window"]
w, h = size(win)
ws, hs = screen_size(win)
@test w <= ws && h <= hs

@testset "Orientation" begin
    img = [1 2; 3 4]
    guidict = imshow(img)
    @test parent(value(guidict["roi"]["image roi"])) == [1 2; 3 4]
    guidict = imshow(img, flipy=true)
    @test parent(value(guidict["roi"]["image roi"])) == [3 4; 1 2]
    guidict = imshow(img, flipx=true)
    @test parent(value(guidict["roi"]["image roi"])) == [2 1; 4 3]
    guidict = imshow(img, flipx=true, flipy=true)
    @test parent(value(guidict["roi"]["image roi"])) == [4 3; 2 1]
end

if Gtk.libgtk_version >= v"3.10"
    # These tests use the player widget
    @testset "Multidimensional" begin
        # Test that we can use positional or named axes with AxisArrays
        img = AxisArray(rand(3, 5, 2), :x, :y, :z)
        guin = imshow(img; name="AxisArray Named")
        @test isa(guin["roi"]["slicedata"].axs[1], Axis{:z})
        guip = imshow(img; axes=(1,2), name="AxisArray Positional")
        @test isa(guip["roi"]["slicedata"].axs[1], Axis{3})

        ## 3d images
        img = testimage("mri")
        hmri = imshow(img; name="P,R view")
        @test isa(hmri["roi"]["slicedata"].axs[1], Axis{:S})

        # Use a custom CLim here because the first slice is not representative of the intensities
        hmrip = imshow(img, Signal(CLim(0.0, 1.0)), axes=(:S, :P), name="S,P view")
        @test isa(hmrip["roi"]["slicedata"].axs[1], Axis{:R})
        push!(hmrip["roi"]["slicedata"].signals[1], 84)

        ## Two coupled images
        mriseg = RGB.(img)
        mriseg[img .> 0.5] = colorant"red"
        # version 1
        guidata = imshow(img, axes=(1,2))
        zr = guidata["roi"]["zoomregion"]
        slicedata = guidata["roi"]["slicedata"]
        guidata2 = imshow(mriseg, nothing, zr, slicedata)
        @test guidata2["roi"]["zoomregion"] === zr

        # version 2
        zr, slicedata = roi(img, (1,2))
        gd = imshow_gui((200, 200), slicedata, (1,2))
        guidata1 = imshow(gd["frame"][1,1], gd["canvas"][1,1], img, nothing, zr, slicedata)
        guidata2 = imshow(gd["frame"][1,2], gd["canvas"][1,2], mriseg, nothing, zr, slicedata)
        showall(gd["window"])
        @test guidata1["zoomregion"] === guidata2["zoomregion"] === zr

        # imlink
        gd = imlink(img, mriseg)
        @test gd["guidata"][1]["zoomregion"] === gd["guidata"][2]["zoomregion"]
    end

    @testset "Non-AbstractArrays" begin
        include("cone.jl")
    end
end

nothing
