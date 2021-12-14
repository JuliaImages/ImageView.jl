using ImageCore
using AxisArrays: AxisArrays, AxisArray, Axis

# Create a cone in 3d that changes color over time
sz = [201, 301, 31]
center = [(s+1)>>1 for s in sz]  # ceil(Int, sz/2)
C3 = Bool[(i-center[1])^2+(j-center[2])^2 <= k^2 for i = 1:sz[1], j = 1:sz[2], k = sz[3]:-1:1]
cmap1 = round.(UInt32, range(0, stop=255, length=60))
cmap = Array{UInt32}(undef, length(cmap1))
for i = 1:length(cmap)
    cmap[i] = cmap1[i]<<16 + cmap1[end-i+1]<<8 + cmap1[i]
end
C4 = Array{UInt32}(undef, sz..., length(cmap))
for i = 1:length(cmap)
    C4[:,:,:,i] = C3*cmap[i]
end
img = AxisArray(reinterpret(RGB24, C4), Axis{:x}(1:size(C4,1)), Axis{:y}(1:size(C4,2)), Axis{:z}(range(1,step=3,length=size(C4,3))), Axis{:time}(1:size(C4,4)))

nothing
