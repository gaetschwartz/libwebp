// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Flutter FFI plugin Swift Package Manager manifest for libwebp_flutter_libs.
// - Depends on FlutterFramework (provided by Flutter's SPM integration at ../FlutterFramework).
// - Depends on libwebp via SDWebImage/libwebp-Xcode (SPM-compatible libwebp build from source).
// - Requires Flutter 3.41+ on the consuming app.
//
// The CocoaPods `libwebp_flutter_libs.podspec` is kept for app projects that have not
// migrated to SPM. Both coexist.

import PackageDescription

let package = Package(
    name: "libwebp_flutter_libs",
    platforms: [
        .iOS("12.0"),
    ],
    products: [
        // Library product name uses hyphens per Flutter plugin SPM conventions;
        // target name keeps underscores to match the plugin name.
        .library(name: "libwebp-flutter-libs", targets: ["libwebp_flutter_libs"]),
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
