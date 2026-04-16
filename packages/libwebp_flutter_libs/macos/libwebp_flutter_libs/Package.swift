// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Flutter FFI plugin Swift Package Manager manifest for libwebp_flutter_libs (macOS).
//
// Mirrors the iOS manifest — see ios/libwebp_flutter_libs/Package.swift for the
// full rationale. In short: the library product is declared `.dynamic` so that
// libwebp's symbols land in their own framework rather than the static link
// line of the Runner binary, avoiding ld64 duplicate-symbol collisions when
// another SPM package in the app also vendors libwebp (e.g. posthog-ios's
// private `phlibwebp` target).

import PackageDescription

let package = Package(
    name: "libwebp_flutter_libs",
    platforms: [
        .macOS("10.14"),
    ],
    products: [
        .library(name: "libwebp-flutter-libs", type: .dynamic, targets: ["libwebp_flutter_libs"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.3.2"),
    ],
    targets: [
        .target(
            name: "libwebp_flutter_libs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "libwebp", package: "libwebp-Xcode"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include/libwebp_flutter_libs"),
            ]
        ),
    ]
)
