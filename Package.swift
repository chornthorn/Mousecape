// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mousecape",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "mousecloak",       targets: ["mousecloak"]),
        .executable(name: "mousecloakHelper", targets: ["mousecloakHelper"]),
    ],
    targets: [

        // MARK: - Shared core library

        /// Shared Swift implementation used by both the mousecloak CLI tool and the
        /// mousecloakHelper daemon (apply/backup/restore/scale/listen/create).
        /// ObjC interop (CGSInternal private APIs, NSCursor private category) is
        /// provided through the existing Xcode-style bridging header via unsafeFlags;
        /// this keeps source-file changes to a minimum during the SPM migration.
        .target(
            name: "MousecloakCore",
            dependencies: [],
            path: "mousecloak",
            exclude: [
                "vendor",
                "CGSInternal",
                "NSCursor_Private.h",
                "mousecloak-Bridging-Header.h",
                "mousecloak-Prefix.pch",
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-import-objc-header",
                    "mousecloak/mousecloak-Bridging-Header.h",
                ]),
            ]
        ),

        // MARK: - Executables

        /// mousecloak – the command-line cursor-management tool.
        /// GBCli dependency removed; argument parsing is now done inline in main.swift.
        .executableTarget(
            name: "mousecloak",
            dependencies: ["MousecloakCore"],
            path: "Sources/mousecloak",
            swiftSettings: [
                .unsafeFlags([
                    "-import-objc-header",
                    "mousecloak/mousecloak-Bridging-Header.h",
                ]),
            ]
        ),

        /// mousecloakHelper – the background daemon that re-applies the active cape on
        /// user-session changes. It shares its cursor-management logic with MousecloakCore.
        .executableTarget(
            name: "mousecloakHelper",
            dependencies: ["MousecloakCore"],
            path: "mousecloakHelper",
            exclude: [
                "mousecloakHelper-Bridging-Header.h",
                "Info.plist",
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-import-objc-header",
                    "mousecloakHelper/mousecloakHelper-Bridging-Header.h",
                ]),
            ]
        ),

        // MARK: - Mousecape app

        /// MousecapeApp – the macOS GUI application (SwiftUI).
        ///
        /// - Note: Producing a full `.app` bundle (with assets and entitlements) requires
        ///   Xcode. Use the `Mousecape.xcodeproj` for that purpose. This SPM target exposes
        ///   the Swift source layer for development tooling, indexing, and unit-testing.
        .target(
            name: "MousecapeApp",
            dependencies: [
                "MousecloakCore",
            ],
            path: "Mousecape",
            exclude: [
                // Non-Swift / build-support files
                "Mousecape-Bridging-Header.h",
                "Mousecape-Prefix.pch",
                "Mousecape-Info.plist",
                "Mousecape.entitlements",
                // Resource bundles (compiled by Xcode, not swift build)
                "Base.lproj",
                "en.lproj",
                "Images.xcassets",
                // Vendor ObjC libraries (kept for Xcode compatibility; not compiled by SPM)
                "external",
                // Xcode localisation export artefact
                "Mousecape",
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-import-objc-header",
                    "Mousecape/Mousecape-Bridging-Header.h",
                ]),
            ]
        ),
    ]
)
