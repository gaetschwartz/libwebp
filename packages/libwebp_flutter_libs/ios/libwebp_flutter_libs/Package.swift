// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Flutter FFI plugin Swift Package Manager manifest for libwebp_flutter_libs (iOS).
//
// This SPM target is INTENTIONALLY a stub — it contains no libwebp sources and no
// libwebp-providing dependency. Rationale:
//
//   SPM has no global symbol dedup (unlike CocoaPods). Any consuming app that also
//   depends on a package which vendors its own libwebp copy (e.g. posthog-ios,
//   which ships `phlibwebp` as a private SPM target in vendor/libwebp/) will hit
//   332+ duplicate libwebp symbols at link time if this plugin also links
//   libwebp-Xcode or similar. See
//   https://github.com/PostHog/posthog-ios/blob/main/Package.swift (phlibwebp target).
//
//   Apple's linker (ld64) has no `--allow-multiple-definition` equivalent, so the
//   clash is unrecoverable at the link stage. The pragmatic fix is to not compete:
//   we don't bundle libwebp here, and the Dart FFI side (`libwebp.dart` on iOS)
//   uses `DynamicLibrary.process()` to look up WebP* symbols wherever they landed
//   in the Runner binary.
//
// Consequences:
//   - In apps that bring libwebp via some other SPM package (posthog, a future
//     first-class SPM port of libwebp, etc.), this plugin works transparently.
//   - In apps with no other libwebp source, Dart FFI lookups will fail at runtime.
//     Such apps should stay on CocoaPods — the `libwebp_flutter_libs.podspec`
//     beside this file still pulls the real `libwebp` pod.
//
// When the SPM ecosystem grows a canonical libwebp package that posthog-ios and
// others adopt, this stub can depend on it and the "stub" caveat goes away.

import PackageDescription

let package = Package(
    name: "libwebp_flutter_libs",
    platforms: [
        .iOS("12.0"),
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
