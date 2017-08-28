using ImageView, FixedPointNumbers, Reactive
using Base.Test

@testset "contrast GUI" begin
    # test for the fix in #119
    img = rand(N0f16, 100, 100)
    clim = Signal(CLim(extrema(img)...))
    imgsig = Signal(img)
    enabled, histsig, imgc = ImageView.prep_contrast(imgsig, clim)
    push!(enabled, true)
    yield()
    ret = ImageView.contrast_gui(enabled, histsig, clim)
    @test isa(ret, Dict)
    Gtk.destroy(ret["window"])
end
