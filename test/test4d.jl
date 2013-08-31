import Images

# Create a cone in 3d that changes color over time
sz = [201, 301, 31]
center = iceil(sz/2)
C3 = Bool[(i-center[1])^2+(j-center[2])^2 <= k^2 for i = 1:sz[1], j = 1:sz[2], k = sz[3]:-1:1]
cmap1 = uint32(linspace(0,255,60))
cmap = Array(Uint32, length(cmap1))
for i = 1:length(cmap)
    cmap[i] = cmap1[i]<<16 + cmap1[end-i+1]<<8 + cmap1[i]
end
C4 = Array(Uint32, sz..., length(cmap))
for i = 1:length(cmap)
    C4[:,:,:,i] = C3*cmap[i]
end
img = Images.Image(C4, ["spatialorder" => ["x", "y", "z"], "timedim" => 4, "colorspace" => "RGB24", "pixelspacing" => [1,1,3]])

