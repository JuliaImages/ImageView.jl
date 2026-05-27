# New in 0.13

- 0.13.3: the legacy string-key shim on `ImageViewGUI` now routes unknown
  keys to the `extras::Dict{Symbol,Any}` field instead of throwing
  `ArgumentError`. This restores the pre-0.13 pattern of using the GUI
  handle as a scratch space for downstream-defined keys (with a depwarn).
  `Base.haskey(::ImageViewGUI, ::AbstractString)` is also defined.
- `imshow` now returns an `ImageDisplay` struct rather than a nested
  `Dict{String,Any}`. The nested GUI and ROI groupings are exposed as
  the structs `ImageViewGUI` (returned by `imshow_gui`) and `ImageROI`
  (returned by the low-level `imshow(::Canvas, ...)`). Field access
  is flattened on `ImageDisplay`, so where you previously wrote
  `result["gui"]["window"]`, `result["roi"]["zoomregion"]`, or
  `result["roi"]["image roi"]`, you can now write `result.window`,
  `result.zoomregion`, `result.image_roi`. Call `propertynames(result)`
  to see every accessible field.

  This change fixes a long-standing usability problem: the default
  `show` for the old `Dict` recursively printed the underlying image
  array, which could hang the REPL for several seconds on a large
  image when the trailing semicolon was forgotten. The new types have
  compact `show` methods that print only summary information.

  The string-key API (`result["gui"]["window"]` etc.) still works and
  routes through a deprecation shim; each call emits a
  `Base.depwarn`. The shim will be removed in the next breaking
  release. Downstream packages can dispatch on `ImageView.ImageDisplay`,
  `ImageView.ImageViewGUI`, or `ImageView.ImageROI` directly.
- Julia 1.10 is now required
- MultiChannelColors, FileIO support now in extensions

# New in 0.12

- switch from Gtk to Gtk4. Fixes REPL lag on Windows.
- Julia 1.6 is now required

# New in 0.11

- switch from GtkReactive to GtkObservables. Reactive was essentially
  unmaintained, and Observables has a stronger technical foundation.
- reductions in latency, particularly on Julia versions >= 1.8.

# New in 0.5

ImageView has been rewritten from scratch. Effort was made to maintain
backward compatibility where possible.

## Breaking changes

- The return value of `imshow` has changed; it is now a `Dict` that
  stores Gtk widgets, Reactive signals, etc.

## Major features

- This package now uses Gtk. Rendering is considerably faster in some
  cases, and the package is faster to load due to precompilation.

- Navigation and zoom region are controlled by GtkReactive/Reactive
  signals, allowing one to more easily extract this information for
  reuse elsewhere.  Examples are shown in the README.

- A new contrast GUI is independent of any plotting package, leading
  to faster loading and faster time-to-first-plot.

- One can now display objects that are not subtypes of
  `AbstractArray`. See `test/cone.jl` for a demonstration.

## Deprecations

- `canvasgrid` now returns more arguments; a deprecation warning
  encourages transitioning to the new syntax

- `pixelspacing` is deprecated as a keyword (use an `AxisArray` instead)

- The `xy` keyword has become `axes`, and it takes dimension integers
  or Symbols (if the image is an AxisArray)
