## External-viewer interface
function imshow(img, range)
    if ndims(img) == 2 
        # only makes sense for gray scale images
        img = imadjustintensity(img, range)
    end
    tmp::String = "tmp.ppm"
    imwrite(img, tmp)
    cmd = `$imshow_cmd $tmp`
    spawn(cmd)
end

imshow(img) = imshow(img, [])

# 'illustrates' fourier transform
ftshow(A::Array{T,2}) where {T} = imshow(log(1+abs(fftshift(A))),[])

