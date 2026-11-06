# spfk-jxl

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-jxl)](https://github.com/ryanfrancesconi/spfk-jxl/tags)
[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-jxl%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-jxl)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-jxl%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-jxl)

JPEG XL encoding for [spfk-image](https://github.com/ryanfrancesconi/spfk-image)'s image converter.
ImageIO reads JPEG XL but cannot write it. This package vendors
[libjxl](https://github.com/libjxl/libjxl) and its dependencies (Highway, skcms, Brotli) as source
and provides `JXLImageEncoder`. The libjxl C API is also available as its own library product.

## Features

- `JXLImageEncoder`, an `ImageFileEncoder` for `public.jpeg-xl`. Its initializer returns `nil` on a
  system that does not declare that type.

## License

The root `LICENSE` (MIT) covers this packaging only. libjxl, Highway, skcms and Brotli are under
their own licenses; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
