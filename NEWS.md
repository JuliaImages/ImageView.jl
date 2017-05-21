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
