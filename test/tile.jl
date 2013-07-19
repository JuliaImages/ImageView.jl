using Tk
using Color
include("testimages.jl")
using TestImages

img = testimage("lighthouse.png")

c = ImageView.canvasgrid(2,2)
ImageView.display(c[1,1], testimage("lighthouse.png"), pixelspacing=[1,1])
ImageView.display(c[1,2], testimage("mountainstream.png", RGB), pixelspacing=[1,1])
ImageView.display(c[2,1], testimage("moonsurface.tiff"), pixelspacing=[1,1])
ImageView.display(c[2,2], testimage("mandrill.tiff"), pixelspacing=[1,1])
