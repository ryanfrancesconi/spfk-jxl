// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-jxl

import PackageDescription

let package = Package(
    name: "spfk-jxl",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "SPFKJXL",
            targets: ["SPFKJXL"]
        ),
        .library(
            name: "libjxl",
            targets: ["libjxl"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-base", from: "1.10.0"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-image", from: "0.1.0"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "1.10.0"),
    ],
    targets: [
        .target(
            name: "libbrotli",
            publicHeadersPath: "c/include",
            cSettings: [
                .unsafeFlags(["-O2"]),
            ]
        ),
        .target(
            name: "libjxl",
            dependencies: ["libbrotli"],
            publicHeadersPath: "lib/include",
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("third_party/highway"),
                .headerSearchPath("third_party/skcms"),
                // libjxl's own CMake flag set; scripts/vendor-libjxl.sh computes the header closure with it.
                .define("NDEBUG"),
                .define("JXL_INTERNAL_LIBRARY_BUILD"),
                .define("JXL_STATIC_DEFINE"),
                .define("JXL_CMS_STATIC_DEFINE"),
                .define("JXL_THREADS_INTERNAL_LIBRARY_BUILD"),
                .define("JXL_THREADS_STATIC_DEFINE"),
                .define("HWY_STATIC_DEFINE"),
                .define("JPEGXL_ENABLE_BOXES", to: "1"),
                .define("JPEGXL_ENABLE_SKCMS", to: "1"),
                .define("JPEGXL_ENABLE_TRANSCODE_JPEG", to: "1"),
                .define("SKCMS_DISABLE_HSW"),
                .define("SKCMS_DISABLE_SKX"),
                .define("FJXL_ENABLE_AVX512", to: "0"),
                .define("HWY_DISABLED_TARGETS", to: "(HWY_AVX3|HWY_AVX3_SPR|HWY_AVX3_ZEN4|HWY_RVV|HWY_SSSE3|HWY_SVE_256)"),
                // Upstream narrows size_t to int throughout; Xcode enables this warning for local packages.
                .disableWarning("shorten-64-to-32"),
                // Highway inlines its SIMD operations only when optimizing; unoptimized, an encode runs about 96× slower.
                // Placed after Xcode's -O0 and -Os, so it applies in every configuration.
                .unsafeFlags(["-O2"]),
            ]
        ),
        .target(
            name: "SPFKJXL",
            dependencies: [
                "libjxl",
                .product(name: "SPFKImage", package: "spfk-image"),
            ]
        ),
        .testTarget(
            name: "SPFKJXLTests",
            dependencies: [
                "SPFKJXL",
                .product(name: "SPFKBase", package: "spfk-base"),
                .product(name: "SPFKImage", package: "spfk-image"),
                .product(name: "SPFKTesting", package: "spfk-testing"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
