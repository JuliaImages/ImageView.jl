# http://juliaimages.github.io/latest/function_reference.html#ImageCore.scalesigned

using Images, TestImages
import ImageView
img = testimage("cameraman")
img1 = img[10:500, 10:500]
img2 = img[12:502, 10:500]
dimg = float(img1)-float(img2)
ss = scalesigned(1)   # replace 1 with whatever scaling you want to encode
cs = colorsigned()
imshow_now(dimg, scalei=x->cs(ss(x)))
