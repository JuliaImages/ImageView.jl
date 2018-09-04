import ImageView
using Colors, Gtk.ShortNames
using TestImages

grid, frames, c = ImageView.canvasgrid((2,2))
Gtk.showall(Window("canvasgrid", 800, 600) |> grid)
imshow(c[1,1], testimage("lighthouse"))
imshow(c[1,2], testimage("mountainstream"))
imshow(c[2,1], testimage("moonsurface"))
imshow(c[2,2], testimage("mandrill"))
sleep(0.01)
