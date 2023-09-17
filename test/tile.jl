import ImageView
using ImageCore
using TestImages

gui = imshow_gui((400, 300), (2, 2); name="canvasgrid")
c = gui["canvas"]
imshow(c[1,1], testimage("lighthouse"))
imshow(c[1,2], testimage("mountainstream"))
imshow(c[2,1], testimage("moonsurface"))
imshow(c[2,2], testimage("mandrill"))
sleep(0.01)
