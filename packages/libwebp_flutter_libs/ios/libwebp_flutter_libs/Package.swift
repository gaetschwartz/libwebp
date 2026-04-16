// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Flutter FFI plugin Swift Package Manager manifest for libwebp_flutter_libs (iOS).
//
// Depends on SDWebImage/libwebp-Xcode (SPM-compatible libwebp build from source) and
// is declared as a DYNAMIC library product. The dynamic-library choice is deliberate:
//
//   SPM has no cross-package symbol dedup (unlike CocoaPods). When another SPM package
//   in the app also bundles libwebp from source — e.g. posthog-ios's private `phlibwebp`
//   target at vendor/libwebp/ — two static copies get fed into the final executable
//   link and Apple's ld64 fails with hundreds of duplicate symbols (no
//   `--allow-multiple-definition` equivalent on Apple).
//
//   By publishing our product as `.dynamic`, SPM builds libwebp into a per-plugin
//   framework/dylib. The static link of the Runner binary sees only the other
//   consumer's symbols (e.g. phlibwebp); our libwebp lives in its own framework
//   alongside Flutter's other embedded frameworks. Different linkage scopes — no
//   collision at link time.
//
//   Dart FFI uses `DynamicLibrary.process()` (see libwebp.dart), which resolves
//   symbols across the entire loaded process — it will find libwebp functions in
//   either place (the Runner binary via phlibwebp, or our framework). Both copies
//   are the same libwebp 1.5.0, so the ABI is identical.
//
// The CocoaPods `libwebp_flutter_libs.podspec` is kept for apps that haven't migrated
// to SPM; both coexist.

import PackageDescription

let package = Package(
    name: "libwebp_flutter_libs",
    platforms: [
        .iOS("12.0"),
    ],
    products: [
        // `.dynamic` isolates libwebp's symbols from the Runner binary's static link
        // line — this is the key lever that lets us coexist with other SPM packages
        // that vendor libwebp. SPM wraps dynamic products into `.framework` bundles
        // on iOS, so App Store bundle-structure rules are respected.
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
