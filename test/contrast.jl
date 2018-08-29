using ImageView, FixedPointNumbers, Reactive, ColorTypes
using Base.Test

@testset "contrast GUI" begin
    # test for the fix in #119
    imgbw = rand(N0f16, 100, 100)
    imgc = rand(RGB, 100, 100)
    for img in (imgbw, imgc)
        clim = ImageView.default_clim(img)
        imgsig = Signal(img)
        enabled, histsig, imgc = ImageView.prep_contrast(imgsig, clim)
        push!(enabled, true)
        yield()
        ret = ImageView.contrast_gui(enabled, histsig, clim)
        if isa(ret, Vector) #one gui dict per channel for color images
            for r in ret
                @test isa(r, Dict)
                Gtk.destroy(r["window"])
            end
        else
            @test isa(ret, Dict)
            Gtk.destroy(ret["window"])
        end
    end
end
