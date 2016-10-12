import ImageView
using Colors
using TestImages

c = ImageView.canvasgrid(2,2)
ImageView.imshow(c[1,1], testimage("lighthouse"), pixelspacing=[1,1])
ImageView.imshow(c[1,2], testimage("mountainstream"), pixelspacing=[1,1])
ImageView.imshow(c[2,1], testimage("moonsurface"), pixelspacing=[1,1])
ImageView.imshow(c[2,2], testimage("mandrill"), pixelspacing=[1,1])
