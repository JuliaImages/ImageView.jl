using ImageView, ImageCore, ImageView.Observables, MultiChannelColors
using Gtk4: Gtk4
using Test

@testset "contrast GUI" begin
    # test for the fix in #119
    imgbw = rand(N0f16, 100, 100)
    imgc = rand(RGB, 100, 100)
    ctemplate = zero(MagentaGreen{Float32})
    imgmcc = [ctemplate(rand(), rand()) for i = 1:100, j = 1:100]
    for img in (imgbw, imgc, imgmcc)
        clim = ImageView.default_clim(img)
        imgsig = Observable(img)
        enabled, histsig, imgc = ImageView.prep_contrast(imgsig, clim)
        enabled[] = true
        ret = ImageView.contrast_gui(enabled, histsig, clim)
        sleep(1.0)
        if isa(ret, Vector) #one gui dict per channel for color images
            for r in ret
                @test isa(r, Dict)
                Gtk4.destroy(r["window"])
            end
        else
            @test isa(ret, Dict)
            Gtk4.destroy(ret["window"])
        end
        # issue #168
        h = histsig[1][]
        fill!(h.weights, 0)
        enabled[] = false
        h = histsig[1][]
        @test_broken sum(h.weights) > 0
    end
end
