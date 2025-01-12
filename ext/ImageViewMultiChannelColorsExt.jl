module ImageViewMultiChannelColorsExt

using MultiChannelColors, GtkObservables
using ImageCore, ImageCore.MappedArrays
import ImageView: default_clim, _deflt_clim, channel_clims, mapped_channel_clims, histsignals,
                 scalechannels, safeminmax, outtype, change_channel, contrast_gui, CLim, GrayLike,
                 _default_clim, channel_clim, nanz

default_clim(img::AbstractArray{C}) where {C<:AbstractMultiChannelColor} = _default_clim(img, eltype(C))

function _deflt_clim(img::AbstractMatrix{C}) where {C<:AbstractMultiChannelColor}
    minval = zero(C)
    maxval = oneunit(C)
    Observable(CLim(minval, maxval))
end

channel_clims(clim::CLim{C}) where {C<:AbstractMultiChannelColor} = map(f->channel_clim(f, clim), ntuple(i -> (c -> Tuple(c)[i]), length(C)))

function mapped_channel_clims(clim::Observable{CLim{C}}) where {C<:AbstractMultiChannelColor}
    inits = channel_clims(clim[])
    return [map!(x -> channel_clim(c -> Tuple(c)[i], x), Observable(inits[1]), clim) for i = 1:length(C)]
end

function histsignals(enabled::Observable{Bool}, img::Observable, clim::Observable{CLim{C}}) where {C<:AbstractMultiChannelColor}
    chanarrays = [map(x->mappedarray(c -> Tuple(c)[i], x), img) for i = 1:length(C)]
    cls = mapped_channel_clims(clim) #note currently this gets called twice, also in contrast gui creation (a bit inefficient/awkward)
    histsigs = [histsignals(enabled, chanarrays[i], cls[i])[1] for i = 1:length(C)]
    return histsigs
end

function scalechannels(::Type{Tout}, cmin::AbstractMultiChannelColor{T}, cmax::AbstractMultiChannelColor{T}) where {T,Tout}
    return x->Tout(ntuple(i -> nanz(scaleminmax(T, Tuple(cmin)[i], Tuple(cmax)[i])(Tuple(x)[i])), length(cmin)))
end

function safeminmax(cmin::C, cmax::C) where {C<:AbstractMultiChannelColor}
    minmaxpairs = ntuple(i -> safeminmax(Tuple(cmin)[i], Tuple(cmax)[i]), length(C))
    return C(first.(minmaxpairs)), C(last.(minmaxpairs))
end

outtype(::Type{C}) where C<:AbstractMultiChannelColor = C

function change_channel(col::CLim{C}, chanlim::CLim{G}, i::Int) where {C<:AbstractMultiChannelColor, G<:GrayLike}
    cmin, cmax = col.min, col.max
    cmin = Base.setindex(cmin, chanlim.min, i)
    cmax = Base.setindex(cmax, chanlim.max, i)
    return CLim(cmin, cmax)
end

function contrast_gui(enabled::Observable{Bool}, hists::Vector, clim::Observable{CLim{C}}) where {C<:AbstractMultiChannelColor}
    N = length(C)
    @assert length(hists) == N #one signal per color channel
    chanlims = channel_clims(clim[])
    csigs = Observable.(chanlims)
    #make sure that changes to individual channels update the color clim signal and vice versa
    for i = 1:N
        Observables.ObservablePair(clim, csigs[i]; f=x->channel_clim(c->Tuple(c)[i], x), g=x->change_channel(clim, x, i))
    end
    names = ["Contrast $i" for i = 1:N]
    cguis = []
    for i=1:length(hists)
        push!(cguis, contrast_gui(enabled, hists[i], csigs[i]; wname = names[i]))
    end
    return cguis
end


end

