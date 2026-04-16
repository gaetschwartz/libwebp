// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Flutter FFI plugin Swift Package Manager manifest for libwebp_flutter_libs (macOS).
//
// Mirrors the iOS manifest — this is a STUB SPM target that does not bundle libwebp.
// See ios/libwebp_flutter_libs/Package.swift for the full rationale; in short, SPM
// cannot dedupe libwebp symbols when more than one package vendors it
// (posthog-ios vendors libwebp as a private `phlibwebp` target), and Apple's
// linker has no equivalent of `--allow-multiple-definition`.
//
// Dart FFI on macOS uses `DynamicLibrary.process()` (see libwebp.dart); libwebp
// symbols must be provided by whichever SPM package in the app actually links
// libwebp (posthog, a future first-class SPM port, etc.). Apps that don't have
// such a package should stay on CocoaPods via the sibling podspec.

import PackageDescription

let package = Package(
    name: "libwebp_flutter_libs",
    platforms: [
        .macOS("10.14"),
    ],
    products: [
        .library(name: "libwebp-flutter-libs", targets: ["libwebp_flutter_libs"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "libwebp_flutter_libs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include/libwebp_flutter_libs"),
            ]
        ),
    ]
)
