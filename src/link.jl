"""
    imlink(imgs...; gridsize=(1,length(imgs)), dims=(1,2))

Show multiple images in a single window, linking higher-dimensional
axes to shared GUI control(s).
"""
function imlink(imgs...; gridsize=imlink_grid(imgs), dims=(1,2))
    zr, slicedata = roi(first(imgs), dims)
    gd = imshow_gui((200, 200), slicedata, gridsize)
    guidata = Vector{Any}(undef, length(imgs))
    for (img, g, i) in zip(imgs, CartesianIndices(gridsize), 1:length(imgs))
        if isa(img, AbstractArray)
            guidata[i] = imshow(gd["frame"][g], gd["canvas"][g], img, nothing, zr, slicedata)
        else
            guidata[i] = imshow(gd["frame"][g], gd["canvas"][g], img, zr, slicedata)
        end
    end
    gd["guidata"] = guidata
    Gtk.showall(gd["window"])
    gd
end

imlink_grid(imgs) = (1,length(imgs))
