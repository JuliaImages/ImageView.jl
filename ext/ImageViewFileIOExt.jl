module ImageViewFileIOExt

using FileIO, ImageView, Gtk4

"""
    imshow()

Choose an image to display via a file dialog.
"""
ImageView.imshow() = imshow(load(open_dialog("Pick an image to display")))

end
