using Images, Colors, ImageView, TestImages

z = ones(10,50);
y = 8; x = 2;
z[y,x] = 0
guidict = imshow_now(z)
idx = annotate!(guidict, AnnotationText(x, y, "x", color=RGB(0,0,1), fontsize=3))
idx2 = annotate!(guidict, AnnotationPoint(x+10, y, shape='.', size=4, color=RGB(1,0,0)))
idx3 = annotate!(guidict, AnnotationPoint(x+20, y-6, shape='.', size=1, color=RGB(1,0,0), linecolor=RGB(0,0,0), scale=true))
idx4 = annotate!(guidict, AnnotationLine(x+10, y, x+20, y-6, linewidth=2, color=RGB(0,1,0)))
idx5 = annotate!(guidict, AnnotationBox(x+10, y, x+20, y-6, linewidth=2, color=RGB(0,0,1)))
idx6 = annotate!(guidict, AnnotationPoints([(x+25, y-3), (x+24, y-3), (x+23, y-3)],
                                           shape='o', size=3, color=RGB(1,0,1),
                                           linecolor=RGB(0,0,0), scale=true))

sleep(0.01)
delete!(guidict, idx)
sleep(0.01)

img = testimage("lighthouse")
guidict = imshow_now(img)
scalebar(guidict, 30; x = 0.1, y = 0.05)
