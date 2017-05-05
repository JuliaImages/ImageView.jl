import ImageView
using Colors, Gtk.ShortNames
using TestImages

grid, frames, c = ImageView.canvasgrid((2,2))
showall(Window("canvasgrid", 800, 600) |> grid)
ImageView.imshow(c[1,1], testimage("lighthouse"))
ImageView.imshow(c[1,2], testimage("mountainstream"))
ImageView.imshow(c[2,1], testimage("moonsurface"))
ImageView.imshow(c[2,2], testimage("mandrill"))
