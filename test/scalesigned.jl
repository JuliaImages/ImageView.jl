# http://juliaimages.github.io/latest/function_reference.html#ImageCore.scalesigned

using ImageCore, TestImages
import ImageView
img = testimage("cameraman")
img1 = img[10:500, 10:500]
img2 = img[12:502, 10:500]
dimg = float(img1)-float(img2)
const ss = scalesigned(1)   # replace 1 with whatever scaling you want to encode
const cs = colorsigned()
imshow_now(dimg, scalei=x->cs(ss(x)))
