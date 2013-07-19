module TestImages
using Images

export testimage

imagedict = [
    "lighthouse.png" => "http://r0k.us/graphics/kodak/kodak/kodim21.png",
    "mountainstream.png" => "http://r0k.us/graphics/kodak/kodak/kodim13.png",
    "moonsurface.tiff" => "http://sipi.usc.edu/database/download.php?vol=misc&img=5.1.09",
    "mandrill.tiff" => "http://sipi.usc.edu/database/download.php?vol=misc&img=4.2.03"
]

function testimage(filename, ops...)
    imagedir = joinpath(Pkg.dir(), "ImageView", "test", "images")
    if !isdir(imagedir)
        mkdir(imagedir)
    end
    imagefile = joinpath(imagedir, filename)
    if !isfile(imagefile)
        download(imagedict[filename], imagefile)
    end
    imread(imagefile, ops...)
end

end
