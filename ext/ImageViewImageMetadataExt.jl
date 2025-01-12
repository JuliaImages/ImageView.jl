module ImageViewImageMetadataExt

using ImageMetadata
import ImageView: _mappedarray

_mappedarray(f, img::ImageMeta) = shareproperties(img, _mappedarray(f, data(img)))

end
