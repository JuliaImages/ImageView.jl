using ImageView, ImageCore, ImageView.Observables, MultiChannelColors
using Gtk4: Gtk4
using GtkObservables: GtkObservables
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

@testset "setup_contrast_popup!" begin
    # dummy_histsig: range is [lo-span/2, hi+span/2] with zero counts
    clim = Observable(CLim(0.2f0, 0.8f0))
    hsig = ImageView.dummy_histsig(clim)
    h = hsig[]
    @test all(iszero, h.weights)
    @test length(h.weights) == 299         # 300-point LinRange → 299 bins
    @test first(h.edges[1]) ≈ -0.1f0       # 0.2 - 0.6/2
    @test last(h.edges[1])  ≈  1.1f0       # 0.8 + 0.6/2

    # degenerate CLim (min == max) falls back to [0,1]-based range
    hsig_degen = ImageView.dummy_histsig(Observable(CLim(0.5f0, 0.5f0)))
    h_degen = hsig_degen[]
    @test first(h_degen.edges[1]) ≈ -0.5f0  # 0 - 1/2
    @test last(h_degen.edges[1])  ≈  1.5f0  # 1 + 1/2

    # dummy_histsigs: 1 signal for GrayLike, 3 for AbstractRGB
    @test length(ImageView.dummy_histsigs(Observable(CLim(0.0f0, 1.0f0)))) == 1
    @test length(ImageView.dummy_histsigs(
        Observable(CLim(RGB(0f0,0f0,0f0), RGB(1f0,1f0,1f0))))) == 3

    # setup_contrast_popup! registers the contrast_gui action on the canvas
    # (gridsize (1,1) default → gd.canvas is a single Canvas, not a matrix)
    gd = imshow_gui((50, 50))
    canvas = gd.canvas
    clim2 = Observable(CLim(0.0f0, 1.0f0))
    n_preserved = length(canvas.preserved)
    ret = setup_contrast_popup!(canvas, clim2)
    @test ret === canvas                                 # returns the canvas
    @test "contrast_gui" in keys(canvas.action_group)
    @test length(canvas.preserved) > n_preserved         # callback was preserved

    # with img kwarg: uses histsignals; action still registered
    gd2 = imshow_gui((50, 50))
    canvas2 = gd2.canvas
    clim3 = Observable(CLim(0.0f0, 1.0f0))
    img  = Observable(rand(Float32, 10, 10))
    setup_contrast_popup!(canvas2, clim3; img=img)
    @test "contrast_gui" in keys(canvas2.action_group)

    Gtk4.destroy(gd.window)
    Gtk4.destroy(gd2.window)
end
