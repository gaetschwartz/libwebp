// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Flutter FFI plugin Swift Package Manager manifest for libwebp_flutter_libs on macOS.
// Mirrors the iOS SPM package — depends on FlutterFramework (provided by Flutter's
// SPM integration) and on libwebp via SDWebImage/libwebp-Xcode.
//
// The CocoaPods `libwebp_flutter_libs.podspec` under macos/ is kept for apps that
// have not migrated to SPM. Both coexist.

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
