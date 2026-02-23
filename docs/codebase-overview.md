# Mousecape Codebase Overview

This document describes the architecture, source files, and relationships between components in the Mousecape project.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Repository Structure](#repository-structure)
3. [Build Targets](#build-targets)
4. [Data Models](#data-models)
5. [Application Layer (GUI)](#application-layer-gui)
   - [App Entry Point](#app-entry-point)
   - [SwiftUI Views](#swiftui-views)
   - [Bridge / Observable Models](#bridge--observable-models)
   - [Legacy AppKit Layer (kept for Xcode)](#legacy-appkit-layer-kept-for-xcode)
   - [Subclasses and Utilities](#subclasses-and-utilities)
   - [Categories](#categories)
6. [mousecloak — CLI Tool](#mousecloak--cli-tool)
7. [mousecloakHelper — Background Daemon](#mousecloakhelper--background-daemon)
8. [External Libraries](#external-libraries)
9. [Private CoreGraphics Headers (CGSInternal)](#private-coregraphics-headers-cgsinternal)
10. [Cape File Format](#cape-file-format)
11. [Component Relationships Diagram](#component-relationships-diagram)
12. [Application Startup and Main Flow](#application-startup-and-main-flow)

---

## Project Overview

**Mousecape** is a free cursor manager for macOS 13 and later. It allows users to replace system-wide cursors with custom ones packaged in a format called a **cape**. A cape is a binary plist file (`.cape`) that contains multiple cursors, each with image representations at different DPI scales and optional animation frames.

Mousecape works by calling the same private CoreGraphics APIs that macOS uses internally to initialize system cursors. Because it hooks into the system at a low level, a background daemon (`mousecloakHelper`) is required to re-apply the selected cape after every user switch or login.

The project is written in **Swift 5** (converted from the original Objective-C codebase). The GUI layer uses **SwiftUI** (macOS 13+). Build artifacts are managed by both **Xcode** (for the full `.app` bundle with assets and entitlements) and **Swift Package Manager** (for the command-line tools and for tooling / unit-testing support).

---

## Repository Structure

```
Mousecape/                          # Repository root
├── Package.swift                   # Swift Package Manager manifest
├── docs/                           # Project documentation (this folder)
├── Sources/
│   └── mousecloak/
│       └── main.swift              # mousecloak executable entry point (ArgParser)
├── Mousecape/                      # GUI application source (also an SPM target: MousecapeApp)
│   ├── MousecapeApp.swift          # SwiftUI @main app entry point
│   ├── MCAppDelegate.swift         # Legacy AppKit delegate (kept for reference, not active)
│   ├── Mousecape-Bridging-Header.h # Bridging header (private CGS APIs, NSCursor_Private)
│   ├── Mousecape-Prefix.pch        # Precompiled header
│   ├── Mousecape-Info.plist        # Bundle configuration
│   ├── Mousecape.entitlements      # App sandbox entitlements
│   ├── Base.lproj/                 # XIB / storyboard resources
│   ├── en.lproj/                   # Localized strings (English)
│   ├── Images.xcassets/            # App icon and image assets
│   ├── external/                   # Vendor ObjC header files (reference only; .m files removed)
│   │   ├── BTRKit/                 # BTRScrollView / BTRClipView headers
│   │   ├── DTScrollView/           # DTScrollView header
│   │   ├── MASPreferences/         # MASPreferences headers (replaced by SwiftUI Settings)
│   │   └── Rebel/                  # RBLScrollView / NSColor+RBLCGColorAdditions headers
│   └── src/                        # Application source code (all Swift)
│       ├── categories/             # Swift extensions
│       ├── controllers/            # AppKit controllers (kept for Xcode compatibility)
│       │   └── Preferences/        # MCGeneralPreferencesController (superseded by SettingsView)
│       ├── models/                 # Data model classes
│       ├── subclasses/             # NSFormatter subclasses
│       └── views/                  # SwiftUI views and legacy NSView subclasses
├── mousecloak/                     # MousecloakCore shared library source (SPM target)
│   ├── apply.swift                 # Apply a cape to the system
│   ├── create.swift                # Create / export capes
│   ├── restore.swift               # Restore default macOS cursors
│   ├── backup.swift                # Back up current cursor state
│   ├── listen.swift                # Daemon listen mode (re-apply on user switch)
│   ├── scale.swift                 # Get / set cursor scale multiplier
│   ├── MCDefs.swift                # Global constants, error codes, cursor map
│   ├── MCPrefs.swift               # Preferences / settings management
│   ├── NSBitmapImageRep+ColorSpace.swift  # Image color-space utilities
│   ├── NSCursor_Private.h          # Private NSCursor API declarations
│   ├── mousecloak-Bridging-Header.h # Bridging header for MousecloakCore (CGSInternal)
│   ├── CGSInternal/                # Private CoreGraphics headers
│   └── vendor/GBCli/               # GBCli headers (reference only; replaced by ArgParser)
├── mousecloakHelper/               # Helper daemon source (SPM target)
│   ├── main.swift                  # Daemon entry point: calls listener() then exits
│   └── mousecloakHelper-Bridging-Header.h
├── Mousecape.xcodeproj/            # Xcode project configuration
├── com.maxrudberg.svanslosbluehazard.cape  # Sample cursor cape
├── README.md                       # Project readme
├── LICENSE                         # BSD 3-Clause license
├── PRIVACY                         # Privacy policy
├── appcast.xml                     # Sparkle update feed
└── screenshot.png                  # App screenshot
```

---

## Build Targets

### Xcode targets (`Mousecape.xcodeproj`)

| Target | Output | Purpose |
|---|---|---|
| `Mousecape` | `Mousecape.app` | Main GUI application for managing and editing capes |
| `mousecloak` | `mousecloak` (binary) | Command-line tool for applying, creating, and converting capes |
| `mousecloakHelper` | `mousecloakHelper` (daemon) | Background login item that re-applies the active cape after every user switch |

> **Note:** Building the full `.app` bundle (with assets, entitlements, and code signing) requires Xcode.

### Swift Package Manager targets (`Package.swift`)

| Target | Kind | Path | Purpose |
|---|---|---|---|
| `MousecloakCore` | library | `mousecloak/` | Shared Swift implementation (apply, backup, create, restore, scale, listen) |
| `mousecloak` | executable | `Sources/mousecloak/` | CLI entry point; depends on `MousecloakCore` |
| `mousecloakHelper` | executable | `mousecloakHelper/` | Daemon entry point; depends on `MousecloakCore` |
| `MousecapeApp` | library | `Mousecape/` | GUI app source layer (SwiftUI); depends on `MousecloakCore` |

> **Note:** `swift build` compiles the command-line tools. Use `Mousecape.xcodeproj` to produce a signed app bundle.

---

## Data Models

Located in `Mousecape/src/models/`. All model files are **Swift**.

### `MCCursor` (`MCCursor.swift`)

Represents a single cursor entry within a cape. A cursor can have multiple image representations at different DPI scales and can be animated.

**Key properties:**

| Property | Type | Description |
|---|---|---|
| `identifier` | `String` | Reverse-DNS cursor identifier (e.g., `com.apple.coregraphics.Arrow`) |
| `name` | `String` | Human-readable cursor name (computed from `identifier`) |
| `frameDuration` | `CGFloat` | Time in seconds between animation frames |
| `frameCount` | `Int` | Number of animation frames stacked vertically in the image |
| `size` | `NSSize` | Logical size of a single cursor frame in points |
| `hotSpot` | `NSPoint` | Coordinates of the cursor's click point within the image |
| `representations` | `NSMutableDictionary` | Map of scale raw value string → `NSBitmapImageRep` |

**Scale enum (`MCCursorScale`):**

```swift
@objc enum MCCursorScale: UInt {
    case none   =    0  // unset
    case scale100  = 100  // 1×, standard resolution
    case scale200  = 200  // 2×, Retina
    case scale500  = 500  // 5×
    case scale1000 = 1000 // 10×
}
```

**Key methods:**

- `init?(cursorDictionary:ofVersion:)` — Deserialize from a cape dictionary.
- `setRepresentation(_:forScale:)` / `representationForScale(_:)` — Get or set the image for a specific scale.
- `dictionaryRepresentation()` — Serialize back to a dictionary for writing to a file.
- `class func composeRepresentation(withFrames:)` — Stack individual frame images vertically into a single sprite sheet.

---

### `MCCursorLibrary` (`MCCursorLibrary.swift`)

Represents a complete cape (a named collection of `MCCursor` objects). Handles serialization, dirty-state tracking, and undo support.

**Key properties:**

| Property | Type | Description |
|---|---|---|
| `name` | `String` | Display name of the cape |
| `author` | `String` | Author name |
| `identifier` | `String` | Unique reverse-DNS bundle identifier |
| `version` | `NSNumber` | Version number |
| `fileURL` | `URL?` | Path to the `.cape` file on disk |
| `cursors` | `NSMutableSet` | The set of `MCCursor` objects in this cape |
| `isDirty` | `Bool` | `true` if there are unsaved changes |
| `isHiDPI` | `Bool` | `true` if the cape includes HiDPI (Retina) representations |
| `undoManager` | `NSUndoManager` | Per-library undo/redo manager |
| `library` | `MCLibraryController?` | Weak reference to the owning controller |

**Key methods:**

- `init?(contentsOfURL:)` — Load from a `.cape` file on disk.
- `init?(dictionary:)` — Create from an in-memory `[String: Any]` dictionary.
- `addCursor(_:)` / `removeCursor(_:)` — Mutate the cursor set.
- `dictionaryRepresentation()` — Serialize the entire library to a dictionary.
- `save()` — Write changes back to `fileURL`; returns an `NSError` on failure.
- `revertToSaved()` — Discard unsaved changes by rewinding the undo manager.

**Relationship:** `MCCursorLibrary` owns a collection of `MCCursor` objects and is owned by `MCLibraryController`.

---

## Application Layer (GUI)

The GUI application is written in **SwiftUI** (macOS 13+). The app entry point is `MousecapeApp.swift`. AppKit bridge models connect the KVO-based `MCLibraryController` / `MCCursorLibrary` objects to the reactive SwiftUI layer.

### App Entry Point

#### `MousecapeApp.swift`

The SwiftUI `@main` app struct. Declares three `Scene`s:

- **`WindowGroup("Mousecape", id: "library")`** — The main library window hosting `LibraryView`.
- **`Window("Edit", id: "edit")`** — The cursor editing window hosting `EditView`.
- **`Settings`** — The settings panel hosting `SettingsView`.

Handles:
- Re-applying the previously active cape on app launch.
- File menu actions: New Cape, Import Cape, Import MightyMouse.
- Helper tool toggle via `SMLoginItemSetEnabled`.

---

#### `MCAppDelegate.swift`

Retained for reference only. The `@NSApplicationMain` attribute has been removed; `MousecapeApp.swift` is the active entry point. No functionality depends on this file.

---

### SwiftUI Views

#### `LibraryView.swift`

Replaces `Library.xib` + `MCLibraryWindowController` + `MCLibraryViewController`.

- `List` of all capes sourced from `LibraryStore.capes`.
- Row context menu: Apply, Edit, Duplicate, Remove, Show in Finder.
- Double-click respects the user preference (apply or edit).
- Toolbar shows the currently applied cape name.
- Dump progress overlay sheet (`ProgressView`) while `store.isDumping` is `true`.

---

#### `CapeRowView.swift`

A single row in the library list. Displays the cape name, author, HiDPI badge, applied checkmark, and a horizontal scrolling strip of `CursorThumbnailView` previews. Backed by `ObservableCape`.

---

#### `EditView.swift`

Replaces `Edit.xib` + `MCEditWindowController` + `MCEditListController` + `MCEditDetailController` + `MCEditCapeController`.

A `NavigationSplitView` with:
- **Sidebar** — Cape name header + list of `MCCursor` entries. Plus/minus buttons for adding/removing cursors.
- **Detail** — `CapeEditorView` (when the cape header is selected) or `CursorEditorView` (when a cursor is selected).
- **Toolbar** — Save, Revert, Apply Cape buttons.

---

#### `CapeEditorView.swift`

Detail panel for editing cape-level metadata (name, author, identifier, version). Backed by `ObservableCursorLibrary`.

---

#### `CursorEditorView.swift`

Detail panel for editing a single `MCCursor` (type, size, hotspot, frame count, frame duration, and image representations at each scale). Hosts `MMAnimatingImageView` wells for drag-and-drop of cursor images.

---

#### `CursorThumbnailView.swift`

A small `NSViewRepresentable` wrapper around `MMAnimatingImageView` used in `CapeRowView` to render animated cursor thumbnails.

---

#### `SettingsView.swift`

Replaces `MASPreferences` + `MCGeneralPreferencesController`. A SwiftUI `Form` in the standard macOS Settings scene providing:
- Handedness picker.
- Double-click action picker (apply or edit).
- Cursor scale slider + text field (calls `setCursorScale()` from `MousecloakCore`).

Uses `@AppStorage` for all preference keys.

---

#### `MMAnimatingImageView.swift`

A Swift `NSView` subclass that:
- Displays a cursor image that may be animated (scrolling through sprite-sheet frames via a timer).
- Accepts and provides drag-and-drop of images (`NSDraggingDestination` / `NSDraggingSource`).
- Draws a crosshair overlay at `hotSpot` when `shouldShowHotSpot` is `true`.
- Communicates drag events back to its delegate (`MMAnimatingImageViewDelegate`).

**Key properties:**

| Property | Description |
|---|---|
| `image` | The sprite-sheet image (frames stacked vertically) |
| `placeholderImage` | Shown when no image is set |
| `frameDuration` | Seconds per animation frame |
| `frameCount` | Total number of frames in the sprite sheet |
| `scale` | DPI scale for rendering (0.0 = inherit from window) |
| `hotSpot` | Hot-spot coordinates shown as a crosshair |
| `shouldAnimate` | Enables/disables the frame animation timer |
| `shouldShowHotSpot` | Shows/hides the crosshair |
| `shouldAllowDragging` | Enables drag-out of the current image |

---

#### `MCCapeCellView.swift`

Legacy `NSTableCellView` subclass kept for Xcode compatibility. The SwiftUI equivalent is `CapeRowView`.

---

#### `MCCapePreviewItem.swift`

Legacy `NSCollectionViewItem` subclass kept for Xcode compatibility.

---

#### `MCSpriteLayer.swift`

A `CALayer` subclass that renders a single frame of a sprite sheet by adjusting `contentsRect`. Used internally by `MMAnimatingImageView`.

---

### Bridge / Observable Models

#### `LibraryStore.swift`

`ObservableObject` bridge between `MCLibraryController` (KVO) and SwiftUI.

- Observes `MCLibraryController.capes` and `.appliedCape` via KVO and republishes them as `@Published` properties.
- Exposes action methods: `importCape`, `removeCape`, `applyCape`, `restoreCape`, `dumpCursors`, `createMightyMouseCape`.
- Passed as an `@EnvironmentObject` to `LibraryView` and `EditView`.

---

#### `ObservableCape` (defined in `CapeRowView.swift`)

Lightweight `NSObject, ObservableObject` wrapper around a single `MCCursorLibrary`. Used as `@ObservedObject` in `CapeRowView`. Observes `name`, `author`, `isHiDPI`, and `cursors` via KVO / typed observation.

---

#### `ObservableCursorLibrary` (defined in `CapeEditorView.swift`)

`NSObject, ObservableObject` wrapper around `MCCursorLibrary` for the edit form. Republishes the mutable properties of the library as `@Published` fields; changes are written back to the underlying model.

---

### Legacy AppKit Layer (kept for Xcode)

The following Swift files remain in the project but are superseded by the SwiftUI layer. They are compiled by Xcode (for backward compatibility / incremental migration) but are **not** referenced by the active app flow:

| File | Replaced by |
|---|---|
| `MCLibraryWindowController.swift` | `LibraryView` + `LibraryStore` |
| `MCLibraryViewController.swift` | `LibraryView` |
| `MCEditWindowController.swift` | `EditView` |
| `MCEditListController.swift` | `EditView` sidebar |
| `MCEditDetailController.swift` | `CursorEditorView` |
| `MCEditCapeController.swift` | `CapeEditorView` |
| `Preferences/MCGeneralPreferencesController.swift` | `SettingsView` |

---

### Subclasses and Utilities

#### `MCFormatters.swift`

Two `NSFormatter` subclasses used in Interface Builder bindings:

- **`MCPointFormatter`** — Formats an `NSPoint` value (e.g., the hotspot) for display in a text field.
- **`MCSizeFormatter`** — Formats an `NSSize` value (e.g., the cursor size) for display in a text field.

---

### Categories

#### `NSFileManager+DirectoryLocations.swift`

Adds convenience methods to `NSFileManager`:
- `findOrCreateDirectory(_:inDomain:appendPathComponent:error:)` — Finds or creates a standard search-path directory.
- `applicationSupportDirectory` — Returns the path to `~/Library/Application Support/Mousecape/`.

Used by `LibraryStore` to locate where cape files are stored.

---

#### `NSOrderedSet+AZSortedInsert.swift`

Adds sorted-insertion methods to `NSOrderedSet` and `NSMutableOrderedSet`:
- `indexForInserting(_:sortedUsing:)` — Binary-search to find the correct insertion index.
- `insert(_:sortedUsing:)` (mutable) — Insert while maintaining sort order.

Used by `MCLibraryController` to keep the `capes` ordered set alphabetically sorted.

---

## mousecloak — CLI Tool

The `mousecloak` command-line tool is split across two SPM targets:

- **`MousecloakCore`** (library, path `mousecloak/`) — all cursor-management logic, shared with `mousecloakHelper`.
- **`mousecloak`** (executable, path `Sources/mousecloak/`) — the entry point with argument parsing.

All source files are **Swift**. The binary is embedded inside `Mousecape.app` and invoked by the GUI via `NSTask`.

### `Sources/mousecloak/main.swift`

Entry point for the `mousecloak` executable. Parses command-line arguments using the inline `ArgParser` struct (GBCli has been removed) and dispatches to the appropriate function from `MousecloakCore`:

| Flag | Function called | Description |
|---|---|---|
| `-a`, `--apply <path>` | `applyCapeAtPath()` | Apply a `.cape` file to the system |
| `-r`, `--reset` | `resetAllCursors()` | Restore default macOS cursors |
| `-c`, `--create <dir>` | `createCape()` | Create a `.cape` from a directory of images |
| `-x`, `--convert <file>` | `createCape(..., convert: true)` | Convert a `.MightyMouse` file to `.cape` |
| `-d`, `--dump <file>` | `dumpCursorsToFile()` | Dump currently applied system cursors to a file |
| `-e`, `--export <file> -o <dir>` | `exportCape()` | Export a `.cape` to a folder of images |
| `-s`, `--scale [value]` | `cursorScale()` / `setCursorScale()` | Get or set the cursor size multiplier |
| `--listen` | `listener()` | Run as a daemon, re-applying the cape on user switch |

#### `ArgParser` struct

Minimal inline argument parser defined at the top of `main.swift`. Provides:
- `has(_:short:)` — whether a flag is present.
- `value(for:short:)` — the value token immediately following a flag.

---

### `apply.swift`

Contains the core cursor-registration logic:

- **`applyCapeAtPath(_ path: String)`** — Loads a `.cape` plist from disk and calls `applyCape()`.
- **`applyCape(_ dictionary: [String: Any])`** — Iterates over cursors in the dictionary and calls `applyCapeForIdentifier()` for each.
- **`applyCapeForIdentifier(_:identifier:restore:)`** — Decodes image data and calls `applyCursorForIdentifier()`.
- **`applyCursorForIdentifier(...)`** — The lowest-level function. Calls the private CoreGraphics API `CGSRegisterCursorWithImages()` via `CGSGetDefaultConnection()` to register the custom cursor globally.

**Depends on:** `MCDefs.swift`, `CGSInternal/CGSCursor.h`, `CGSInternal/CGSConnection.h`.

---

### `create.swift`

Handles creation and export of capes:

- **`createCape(_:output:convert:)`** — Entry point. If `convert` is `true`, reads a `.MightyMouse` dictionary; otherwise, reads a directory of cursor folders. Calls `createCapeFromDirectory()` or `createCapeFromMightyMouse()` and writes the result to disk.
- **`createCapeFromDirectory(_ path: String)`** — Reads a folder where each sub-folder is named after a cursor identifier and contains numbered PNG frames (`0.png`, `1.png`, …). Stacks frames using `MCCursor.composeRepresentation(withFrames:)`.
- **`createCapeFromMightyMouse(_:metadata:)`** — Converts the legacy MightyMouse plist format to the Mousecape cape dictionary format.
- **`dumpCursorsToFile(_:progress:)`** — Reads the currently registered system cursors (using `CGSCopyRegisteredCursorImages`) and writes them to a new `.cape` file.
- **`exportCape(_:destination:)`** — Writes each cursor's frames as individual PNG files in sub-folders, reversing the cape format back to a directory tree.

**Depends on:** `MCDefs.swift`, `CGSInternal/CGSCursor.h`, `NSBitmapImageRep+ColorSpace.swift`.

---

### `restore.swift`

- **`resetAllCursors()`** — Iterates over all default cursor identifiers and calls `restoreCursorForIdentifier()` for each.
- **`restoreCursorForIdentifier(_ ident: String)`** — Reads the backed-up image data for a cursor and re-registers the original cursor via `CGSRegisterCursorWithImages()`.
- **`restoreStringForIdentifier(_ identifier: String)`** — Returns the file path used to store the backup for a given identifier.

**Depends on:** `backup.swift`, `apply.swift`, `MCDefs.swift`.

---

### `backup.swift`

- **`backupAllCursors()`** — Dumps all current system cursors to a backup folder before applying a cape, so they can be restored later.
- **`backupCursorForIdentifier(_ ident: String)`** — Reads the current CGS cursor and saves its raw data to a backup file.
- **`backupStringForIdentifier(_ identifier: String)`** — Returns the file path used to store the backup for a given identifier (`~/Library/Application Support/Mousecape/backups/<identifier>`).

---

### `listen.swift`

- **`listener()`** — A blocking function that runs a `CFRunLoop`. It registers for `kCGSNotificationUserSessionDidBecomeActive` CoreGraphics session notifications. Each time a user session becomes active (login or fast-user switch), it reads the currently applied cape path from preferences and calls `applyCapeAtPath()` to re-apply it.

**Depends on:** `apply.swift`, `MCPrefs.swift`, `CGSInternal/CGSSession.h`, `CGSInternal/CGSNotifications.h`.

---

### `scale.swift`

- **`cursorScale()`** — Returns the current cursor scale multiplier from the system.
- **`defaultCursorScale()`** — Returns the default (1.0) scale.
- **`setCursorScale(_ scale: Float)`** — Writes the desired scale to preferences and applies it to the current CGS connection.

---

### `MCDefs.swift`

Global constants and utilities shared across `MousecloakCore` and the GUI app:

- **Logging functions:** `MMLog(_:)` / `MMOut(_:)` for stdout output.
- **Dictionary key constants:** `MCCursorDictionaryFrameCountKey`, `MCCursorDictionaryHotSpotXKey`, etc. — keys used in `.cape` plist files.
- **Error codes:** `MCErrorCode` enum with values such as `MCErrorInvalidCapeCode`.
- **Version constants:** `MCCursorCreatorVersion`, `MCCursorParserVersion`.
- **`cursorMap()`** — Returns the mapping from cursor identifier to system cursor type.
- **`nameForCursorIdentifier()` / `cursorIdentifierForName()`** — Bidirectional lookup between reverse-DNS identifiers and human-readable names.
- **`defaultCursors`** — Array of all standard macOS cursor identifiers.

---

### `MCPrefs.swift`

Thin wrapper around `NSUserDefaults` for persisting settings:
- The path of the currently applied cape (per user).
- The cursor scale multiplier.

---

### `NSBitmapImageRep+ColorSpace.swift`

A Swift extension on `NSBitmapImageRep` that adds color-space conversion utilities. Used in `create.swift` when reading and compositing cursor images to ensure consistent color representation.

---

### `NSCursor_Private.h`

Declares private `NSCursor` methods and constants not in the public SDK headers. Included via the bridging header.

---

## mousecloakHelper — Background Daemon

Located in `mousecloakHelper/` (SPM target `mousecloakHelper`).

### `main.swift`

The entire helper daemon is a single Swift file:

```swift
import Foundation

autoreleasepool {
    listener()
}
```

It immediately calls `listener()` (from `MousecloakCore`'s `listen.swift`) and blocks indefinitely on the `CFRunLoop`. The daemon is registered as a **login item** via `SMLoginItemSetEnabled` from the main app. macOS will launch it at login and after user switches, keeping cursors applied persistently.

**Bundle ID:** `com.alexzielenski.mousecloakhelper`

---

## External Libraries

Located in `Mousecape/external/`.

> **Note:** All ObjC `.m` implementation files for the vendor libraries have been removed. Only the `.h` header files are kept for reference and Xcode compatibility. These libraries are **not compiled** by either Xcode or SPM in the current build.

| Library | Status | Purpose |
|---|---|---|
| **BTRKit** | Headers only | Custom `NSScrollView`/`NSClipView` subclasses — superseded by SwiftUI `ScrollView` |
| **DTScrollView** | Headers only | Additional scroll view — superseded by SwiftUI `ScrollView` |
| **MASPreferences** | Headers only | Tabbed preferences window — superseded by SwiftUI `Settings` scene (`SettingsView`) |
| **Rebel** | Headers only | `RBLScrollView`, `NSColor+RBLCGColorAdditions` — superseded by SwiftUI |

**GBCli** (in `mousecloak/vendor/GBCli/`):

> **Note:** GBCli has been replaced by the inline `ArgParser` struct in `Sources/mousecloak/main.swift`. The header files are kept for reference only.

| Class | Purpose |
|---|---|
| `GBSettings` | Key-value store for parsed CLI arguments (replaced by `ArgParser`) |
| `GBCommandLineParser` | Tokenises `argv` (replaced by `ArgParser`) |
| `GBOptionsHelper` | Prints formatted help text (replaced by `printHelp()` in `main.swift`) |

---
## Private CoreGraphics Headers (CGSInternal)

Located in `mousecloak/CGSInternal/`. These are reverse-engineered headers for private Apple frameworks. **They are not part of any public SDK.**

| Header | Contents |
|---|---|
| `CGSConnection.h` | `CGSConnectionID` type; `CGSGetDefaultConnection()` |
| `CGSCursor.h` | Cursor registration APIs: `CGSRegisterCursorWithImages`, `CGSCopyRegisteredCursorImages`, `CGSSetRegisteredCursor`, `CoreCursorUnregisterAll`, etc. |
| `CGSSession.h` | Session notification types; used by `listen.swift` to detect user switches |
| `CGSNotifications.h` | Notification constants (e.g., `kCGSNotificationUserSessionDidBecomeActive`) |
| `CGSAccessibility.h` | Accessibility-related CGS functions |
| `CGSInternal.h` | Umbrella include for the other CGS headers |
| `CGSMisc.h` | Miscellaneous private CGS types |
| `CGSWindow.h`, `CGSRegion.h`, etc. | Other private window-server APIs (not directly used by Mousecape) |

---

## Cape File Format

A `.cape` file is a binary property list (plist) with the following top-level structure:

```
{
  "name"       : <string>   // Display name of the cape
  "author"     : <string>   // Author name
  "identifier" : <string>   // Reverse-DNS unique identifier, e.g. "com.example.MyCursors"
  "version"    : <number>   // Format version (2.0 as of this writing)
  "cloud"      : <bool>     // Whether the cape was sourced from iCloud
  "HiDPI"      : <bool>     // Whether HiDPI representations are present
  "Cursors"    : {          // Dictionary keyed by cursor identifier
    "com.apple.coregraphics.Arrow" : {
      "FrameCount"    : <integer>   // Number of animation frames
      "FrameDuration" : <number>    // Seconds per frame
      "HotSpotX"      : <number>    // Hot-spot X coordinate
      "HotSpotY"      : <number>    // Hot-spot Y coordinate
      "PointsWide"    : <number>    // Width in points
      "PointsHigh"    : <number>    // Height in points
      "Representations" : {
        "100" : <data>   // PNG image data at 1× scale (sprite sheet)
        "200" : <data>   // PNG image data at 2× scale
        "500" : <data>   // PNG image data at 5× scale
        "1000": <data>   // PNG image data at 10× scale
      }
    },
    "com.apple.coregraphics.Wait" : { ... },
    ...
  }
}
```

**Animated cursors:** All animation frames are stacked vertically in a single PNG. The image height equals `PointsHigh × FrameCount`. The cursor engine steps through the image from top to bottom, displaying one `PointsHigh`-tall slice per frame at intervals of `FrameDuration` seconds.

**Cursor identifiers** follow the reverse-DNS pattern `com.apple.coregraphics.<Name>` for system cursors or `com.apple.cursor.<N>` for indexed cursors. The full list is defined in `MCDefs.swift` as `defaultCursors`.

---

## Component Relationships Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                          Mousecape.app                                 │
│                                                                        │
│  MousecapeApp.swift (@main SwiftUI App)                                │
│               │                                                        │
│               ├── LibraryView (WindowGroup "library")                  │
│               │       │ @EnvironmentObject                             │
│               │       └── LibraryStore ──► MCLibraryController        │
│               │               │  (KVO bridge, ObservableObject)       │
│               │               │                                        │
│               │               ├── MCCursorLibrary[] ◄── .cape files   │
│               │               │       └── MCCursor[]                  │
│               │               │                                        │
│               │               └── (invokes mousecloak binary)         │
│               │                                                        │
│               ├── EditView (Window "edit")                             │
│               │   NavigationSplitView                                  │
│               │       ├── sidebar: cursor list                         │
│               │       └── detail: CapeEditorView / CursorEditorView   │
│               │               └── MMAnimatingImageView × 4 scales     │
│               │                                                        │
│               └── Settings scene                                       │
│                       └── SettingsView                                 │
│                                                                        │
└───────────────────────────────┬────────────────────────────────────────┘
                                │ NSTask --apply / --reset / --scale
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                           mousecloak (CLI)                             │
│                                                                        │
│  Sources/mousecloak/main.swift (ArgParser)                             │
│    │                                                                   │
│    ├── apply.swift ──────────────────────────────────────────────┐    │
│    │   applyCapeAtPath()                                          │    │
│    │   applyCape()                                                │    │
│    │   applyCapeForIdentifier()                                   │    │
│    │   applyCursorForIdentifier() ──► CGSRegisterCursorWithImages │    │
│    │                                  (private CoreGraphics API)  │    │
│    ├── create.swift                                               │    │
│    │   createCape() / createCapeFromDirectory()                   │    │
│    │   dumpCursorsToFile() ──► CGSCopyRegisteredCursorImages      │    │
│    │   exportCape()                                               │    │
│    ├── restore.swift ──► backup.swift ──► apply.swift             │    │
│    │   resetAllCursors()                                          │    │
│    ├── scale.swift ──► MCPrefs.swift                              │    │
│    └── listen.swift ──► CGSNotifications ──► applyCapeAtPath()    │    │
│                                                                   │    │
│  CGSInternal/ (private headers) ◄─────────────────────────────────┘   │
│  MCDefs.swift (cursor map, constants)                                  │
│  MCPrefs.swift (NSUserDefaults)                                        │
└────────────────────────────────────────────────────────────────────────┘
                                │ SMLoginItemSetEnabled
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                      mousecloakHelper (daemon)                         │
│                                                                        │
│  main.swift ──► listener() ──► (blocks on CFRunLoop)                  │
│                 │                                                      │
│                 └── On user-switch notification:                       │
│                         applyCapeAtPath(currentCapePath)               │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Application Startup and Main Flow

### 1. App Launch

1. macOS executes `Mousecape.app/Contents/MacOS/Mousecape`.
2. SwiftUI initialises `MousecapeApp` (the `@main` struct).
3. `LibraryStore` is created as a `@StateObject`; its `init` creates `MCLibraryController` and starts KVO observation.
4. `MCLibraryController` scans `~/Library/Application Support/Mousecape/capes/` for `.cape` files, deserialises each into an `MCCursorLibrary`, and populates the `capes` ordered set.
5. `LibraryStore` receives the KVO change, sorts the capes, and publishes them to `LibraryView`.
6. `LibraryView.onAppear` re-applies the previously active cape via `store.applyCape(_:)`.

### 2. Applying a Cape

1. The user selects a cape in `LibraryView` and chooses "Apply" from the context menu (or double-clicks when the preference is set to "apply").
2. `LibraryView` calls `store.applyCape(_:)`.
3. `LibraryStore` calls `MCLibraryController.applyCape(_:)`.
4. `MCLibraryController` serialises the `MCCursorLibrary` to a temporary `.cape` file and launches the `mousecloak` binary (via `NSTask`) with `--apply <path>`.
5. `mousecloak` calls `applyCapeAtPath()` → `applyCape()` → `applyCapeForIdentifier()` → `applyCursorForIdentifier()`.
6. `CGSRegisterCursorWithImages()` registers each cursor image in the window server globally.
7. The cursor changes are immediately visible system-wide.
8. `LibraryStore` saves the applied cape identifier to `UserDefaults`.

### 3. Editing a Cape

1. The user double-clicks a cape (or chooses "Edit" from the context menu).
2. `LibraryView` sets `store.editingCape` and calls `openWindow(id: "edit")`.
3. `EditView.onReceive(store.$editingCape)` wraps the cape in an `ObservableCursorLibrary` and resets the selection to the cape header row.
4. The user selects a cursor in the sidebar; the detail panel switches to `CursorEditorView`.
5. The user drags a PNG onto one of the `MMAnimatingImageView` scale wells.
6. `CursorEditorView` calls `cursor.setRepresentation(_:forScale:)` on the `MCCursor`.
7. `MCCursorLibrary` marks itself as dirty.
8. The user clicks **Save**; `EditView` calls `obs.library.save()` which writes the plist to `fileURL`.

### 4. Creating a Cape from Scratch

1. User presses ⌘N (or chooses File → New Cape).
2. `MousecapeApp` calls `store.importCape(MCCursorLibrary())` with a new empty `MCCursorLibrary`.
3. `MCLibraryController` copies it into the library folder, adds it to the `capes` set, and `LibraryStore` publishes the update.
4. The user opens the edit window, adds cursors, drags in images, and saves.

### 5. Helper Daemon (mousecloakHelper)

1. On first launch, the user chooses **Mousecape → Install Helper Tool**.
2. `MousecapeApp.toggleHelperTool()` calls `SMLoginItemSetEnabled("com.alexzielenski.mousecloakhelper", true)`.
3. macOS registers the helper as a per-user launchd agent.
4. `mousecloakHelper` starts and calls `listener()`, blocking on a `CFRunLoop`.
5. Whenever the user logs in or fast-user-switches, CoreGraphics fires `kCGSNotificationUserSessionDidBecomeActive`.
6. `listener()` reads the last applied cape path from `NSUserDefaults` and calls `applyCapeAtPath()`.
7. The custom cursors are restored without any user interaction.
