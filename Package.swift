// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mousecape",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .executable(name: "mousecloak",       targets: ["mousecloak"]),
        .executable(name: "mousecloakHelper", targets: ["mousecloakHelper"]),
    ],
    targets: [

        // MARK: - ObjC vendor libraries

        /// Command-line argument parsing library used by the mousecloak tool.
        .target(
            name: "GBCli",
            path: "mousecloak/vendor/GBCli",
            publicHeadersPath: ".",
            cSettings: [
                // GBCli requires ARC even though the mousecloak target disables it globally.
                .unsafeFlags(["-fobjc-arc"]),
            ]
        ),

        /// MASPreferences – preferences-window controller used by the Mousecape app.
        .target(
            name: "MASPreferences",
            path: "Mousecape/external/MASPreferences",
            publicHeadersPath: "."
        ),

        /// BTRKit – custom clip/scroll view components used by the Mousecape app.
        .target(
            name: "BTRKit",
            path: "Mousecape/external/BTRKit",
            publicHeadersPath: "."
        ),

        /// Rebel – additional scroll-view components used by the Mousecape app.
        /// Some files in this library must be compiled without ARC.
        .target(
            name: "Rebel",
            path: "Mousecape/external/Rebel",
            publicHeadersPath: ".",
            cSettings: [
                .unsafeFlags(["-fno-objc-arc"]),
            ]
        ),

        /// DTScrollView – elastic scroll view used by the Mousecape app.
        .target(
            name: "DTScrollView",
            path: "Mousecape/external/DTScrollView",
            publicHeadersPath: "."
        ),

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
        .executableTarget(
            name: "mousecloak",
            dependencies: ["MousecloakCore", "GBCli"],
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

        /// MousecapeApp – the macOS GUI application.
        ///
        /// - Note: Producing a full `.app` bundle (with XIBs, entitlements, and embedded
        ///   frameworks such as Sparkle) requires Xcode. Use the `Mousecape.xcodeproj` for
        ///   that purpose. This SPM target exposes the Swift source layer for development
        ///   tooling, indexing, and unit-testing purposes.
        .target(
            name: "MousecapeApp",
            dependencies: [
                "MousecloakCore",
                "MASPreferences",
                "BTRKit",
                "Rebel",
                "DTScrollView",
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
                // Vendor ObjC libraries handled as separate targets above
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
