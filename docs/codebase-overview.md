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
   - [Window Controllers](#window-controllers)
   - [View Controllers](#view-controllers)
   - [Views](#views)
   - [Subclasses and Utilities](#subclasses-and-utilities)
   - [Categories](#categories)
6. [mousecloak — CLI Daemon](#mousecloak--cli-daemon)
7. [mousecloakHelper — Background Daemon](#mousecloakhelper--background-daemon)
8. [External Libraries](#external-libraries)
9. [Private CoreGraphics Headers (CGSInternal)](#private-coregraphics-headers-cgsinternal)
10. [Cape File Format](#cape-file-format)
11. [Component Relationships Diagram](#component-relationships-diagram)
12. [Application Startup and Main Flow](#application-startup-and-main-flow)

---

## Project Overview

**Mousecape** is a free cursor manager for macOS 10.13 and later. It allows users to replace system-wide cursors with custom ones packaged in a format called a **cape**. A cape is a binary plist file (`.cape`) that contains multiple cursors, each with image representations at different DPI scales and optional animation frames.

Mousecape works by calling the same private CoreGraphics APIs that macOS uses internally to initialize system cursors. Because it hooks into the system at a low level, a background daemon (`mousecloakHelper`) is required to re-apply the selected cape after every user switch or login.

---

## Repository Structure

```
Mousecape/                          # Repository root
├── docs/                           # Project documentation (this folder)
├── Mousecape/                      # Xcode project folder
│   ├── Mousecape/                  # Main GUI application source
│   │   ├── main.m                  # App entry point
│   │   ├── MCAppDelegate.{h,m}     # Application delegate
│   │   ├── Mousecape-Info.plist    # Bundle configuration (version, entitlements, etc.)
│   │   ├── Mousecape.entitlements  # App sandbox entitlements
│   │   ├── Mousecape-Prefix.pch    # Precompiled header
│   │   ├── Base.lproj/             # Main storyboard / XIB resources
│   │   ├── en.lproj/               # Localized strings (English)
│   │   ├── Images.xcassets/        # App icon and image assets
│   │   ├── external/               # Embedded third-party libraries
│   │   │   ├── BTRKit/             # Custom scroll view (BTRScrollView, BTRClipView)
│   │   │   ├── DTScrollView/       # Another scroll view implementation
│   │   │   ├── MASPreferences/     # Preferences window framework
│   │   │   ├── Rebel/              # Scroll view framework (RBLScrollView)
│   │   │   └── Sparkle/            # Automatic update framework
│   │   └── src/                    # Application source code
│   │       ├── categories/         # Objective-C category extensions
│   │       ├── controllers/        # View and window controllers
│   │       │   └── Preferences/    # Preferences controller
│   │       ├── models/             # Data model classes
│   │       ├── subclasses/         # NSFormatter subclasses
│   │       └── views/              # Custom view classes
│   ├── mousecloak/                 # CLI tool / daemon source
│   │   ├── main.m                  # CLI entry point (argument parsing)
│   │   ├── apply.{h,m}             # Apply a cape to the system
│   │   ├── create.{h,m}            # Create / export capes
│   │   ├── restore.{h,m}           # Restore default macOS cursors
│   │   ├── backup.{h,m}            # Back up current cursor state
│   │   ├── listen.{h,m}            # Daemon listen mode (re-apply on user switch)
│   │   ├── scale.{h,m}             # Get / set cursor scale multiplier
│   │   ├── MCDefs.{h,m}            # Global constants, error codes, cursor map
│   │   ├── MCPrefs.{h,m}           # Preferences / settings management
│   │   ├── NSBitmapImageRep+ColorSpace.{h,m}  # Image colorspace utilities
│   │   ├── NSCursor_Private.h      # Private NSCursor API declarations
│   │   ├── CGSInternal/            # Private CoreGraphics headers
│   │   └── vendor/GBCli/           # Command-line argument parsing library
│   ├── mousecloakHelper/           # Background helper daemon
│   │   └── main.m                  # Daemon entry point (calls listener())
│   └── Mousecape.xcodeproj/        # Xcode project configuration
├── com.maxrudberg.svanslosbluehazard.cape  # Sample cursor cape
├── README.md                       # Project readme
├── LICENSE                         # BSD 3-Clause license
├── PRIVACY                         # Privacy policy
├── appcast.xml                     # Sparkle update feed (local copy; app uses appcast_signed.xml on GitHub)
└── screenshot.png                  # App screenshot
```

---

## Build Targets

The Xcode project contains three build targets:

| Target | Output | Purpose |
|---|---|---|
| `Mousecape` | `Mousecape.app` | Main GUI application for managing and editing capes |
| `mousecloak` | `mousecloak` (binary) | Command-line tool for applying, creating, and converting capes |
| `mousecloakHelper` | `mousecloakHelper` (daemon) | Background login item that re-applies the active cape after every user switch |

---

## Data Models

Located in `Mousecape/src/models/`.

### `MCCursor` (`MCCursor.h` / `MCCursor.m`)

Represents a single cursor entry within a cape. A cursor can have multiple image representations at different DPI scales and can be animated.

**Key properties:**

| Property | Type | Description |
|---|---|---|
| `identifier` | `NSString` | Reverse-DNS cursor identifier (e.g., `com.apple.coregraphics.Arrow`) |
| `name` | `NSString` | Human-readable cursor name |
| `frameDuration` | `CGFloat` | Time in seconds between animation frames |
| `frameCount` | `NSUInteger` | Number of animation frames stacked vertically in the image |
| `size` | `NSSize` | Logical size of a single cursor frame in points |
| `hotSpot` | `NSPoint` | Coordinates of the cursor's click point within the image |
| `representations` | `NSDictionary` | Map of `MCCursorScale` → `NSImageRep` |

**Scale enum (`MCCursorScale`):**

```
MCCursorScaleNone =    0  (unset)
MCCursorScale100  =  100  (1×, standard resolution)
MCCursorScale200  =  200  (2×, Retina)
MCCursorScale500  =  500  (5×)
MCCursorScale1000 = 1000  (10×)
```

**Key methods:**

- `+cursorWithDictionary:ofVersion:` — Deserialize from a cape dictionary.
- `-setRepresentation:forScale:` / `-representationForScale:` — Get or set the image for a specific scale.
- `-dictionaryRepresentation` — Serialize back to a dictionary for writing to a file.
- `+composeRepresentationWithFrames:` — Stack individual frame images vertically into a single sprite sheet.

---

### `MCCursorLibrary` (`MCCursorLibrary.h` / `MCCursorLibrary.m`)

Represents a complete cape (a named collection of `MCCursor` objects). Handles serialization, dirty-state tracking, and undo support.

**Key properties:**

| Property | Type | Description |
|---|---|---|
| `name` | `NSString` | Display name of the cape |
| `author` | `NSString` | Author name |
| `identifier` | `NSString` | Unique reverse-DNS bundle identifier |
| `version` | `NSNumber` | Version number |
| `fileURL` | `NSURL` | Path to the `.cape` file on disk |
| `cursors` | `NSSet` | The set of `MCCursor` objects in this cape |
| `dirty` | `BOOL` | `YES` if there are unsaved changes |
| `hiDPI` | `BOOL` | `YES` if the cape includes HiDPI (Retina) representations |
| `undoManager` | `NSUndoManager` | Per-library undo/redo manager |
| `library` | `MCLibraryController` | Weak reference to the owning controller |

**Key methods:**

- `+cursorLibraryWithContentsOfURL:` — Load from a `.cape` file on disk.
- `+cursorLibraryWithDictionary:` — Create from an in-memory NSDictionary.
- `-addCursor:` / `-removeCursor:` — Mutate the cursor set.
- `-dictionaryRepresentation` — Serialize the entire library to a dictionary.
- `-save` — Write changes back to `fileURL`.
- `-revertToSaved` — Discard unsaved changes and reload from disk.

**Relationship:** `MCCursorLibrary` owns a collection of `MCCursor` objects and is owned by `MCLibraryController`.

---

## Application Layer (GUI)

### App Entry Point

#### `main.m`

The standard Cocoa entry point. Calls `NSApplicationMain()`, which loads `MainMenu.xib`, instantiates `NSApplication`, and sets `MCAppDelegate` as the application delegate.

---

#### `MCAppDelegate` (`MCAppDelegate.h` / `MCAppDelegate.m`)

The NSApplicationDelegate. Responsible for:

- **App launch:** Creates and shows `MCLibraryWindowController`. Re-applies the currently selected cape on startup.
- **File opening:** Handles `.cape` files opened via Finder (double-click) by calling `MCLibraryController -importCapeAtURL:`.
- **Helper tool management:** Installs or uninstalls `mousecloakHelper` as a launchd login item using `SMLoginItemSetEnabled`.
- **Preferences window:** Lazily creates a `MASPreferencesWindowController` containing `MCGeneralPreferencesController`.
- **Menu actions:** `newDocument:`, `openDocument:`, `convertCape:` (from MightyMouse format), `restoreCape:`, `showPreferences:`.

**Imports / depends on:** `MCLibraryWindowController`, `MCLibraryViewController`, `MCLibraryController`, `MCCursorLibrary`, `create.h` (for `createCapeFromMightyMouse`), `MASPreferencesWindowController`, `MCGeneralPreferencesController`.

---

### Window Controllers

#### `MCLibraryWindowController` (`MCLibraryWindowController.h` / `MCLibraryWindowController.m`)

The main application window. Hosts `MCLibraryViewController` and shows a progress bar (`NSProgressIndicator`) when dumping or applying capes.

**Outlets:**
- `libraryViewController` — The embedded list view controller.
- `appliedAccessory` — A view shown when a cape is applied.
- `progressBar` / `progressField` — Progress UI shown during long operations.

**Also defines:** `MCAppliedCapeValueTransformer` — An `NSValueTransformer` that converts a cape object into a display string for the applied-cape accessory view.

---

#### `MCEditWindowController` (`MCEditWindowController.h` / `MCEditWindowController.m`)

The cursor editing window. Uses an `NSSplitView` to display three panels side by side:

1. **Left panel** — `MCEditListController` (list of cursors in the cape being edited).
2. **Centre panel** — `MCEditDetailController` or `MCEditCapeController` depending on selection.
3. The `cursorLibrary` property is set by `MCLibraryViewController` when the user clicks "Edit".

---

### View Controllers

#### `MCLibraryViewController` (`MCLibraryViewController.h` / `MCLibraryViewController.m`)

An `NSViewController` that owns the main table view listing all available capes.

**Responsibilities:**
- Acts as `NSTableViewDelegate` and `NSTableViewDataSource` for the cape list.
- Manages selection state (`selectedCape`, `clickedCape`, `editingCape`).
- Provides a context menu (`contextMenu`) for cape operations (apply, delete, duplicate, export, edit).
- Opens `MCEditWindowController` when editing a cape.
- Holds a strong reference to `MCLibraryController`.

---

#### `MCLibraryController` (`MCLibraryController.h` / `MCLibraryController.m`)

The core business-logic controller. Does **not** have a view; it manages the in-memory collection of capes and coordinates all disk and system interactions.

**Responsibilities:**
- Maintains the `capes` ordered set (list of `MCCursorLibrary` objects).
- Loads capes from `~/Library/Application Support/Mousecape/capes/` on startup.
- `importCapeAtURL:` / `importCape:` — Copy a cape into the library folder and add it to the set.
- `addCape:` / `removeCape:` — Add or remove a `MCCursorLibrary` from the collection.
- `applyCape:` — Serialize the cape to a temporary file and invoke the `mousecloak` tool with `--apply`.
- `restoreCape` — Invoke `mousecloak --reset` to restore default macOS cursors.
- `dumpCursorsWithProgressBlock:` — Use `mousecloak --dump` to export current system cursors.
- Tracks `appliedCape` (weak reference) and persists the applied cape's identifier in `NSUserDefaults`.

---

#### `MCEditListController` (`MCEditListController.h` / `MCEditListController.m`)

A table view controller showing the list of `MCCursor` objects inside the cape being edited.

**Responsibilities:**
- Displays cursor names and preview icons.
- `addAction:` — Adds a new blank `MCCursor` to `cursorLibrary`.
- `removeAction:` — Removes the selected `MCCursor`.
- `duplicateAction:` — Copies the selected cursor.
- Selection is communicated to `MCEditWindowController` which updates the detail panel.

---

#### `MCEditDetailController` (`MCEditDetailController.h` / `MCEditDetailController.m`)

Shows the full detail view for a single `MCCursor`. Allows editing all properties and image representations.

**Outlets:**
- `typePopUpButton` — Selects the cursor identifier from a predefined list.
- `rep100View`, `rep200View`, `rep500View`, `rep1000View` — Four `MMAnimatingImageView` instances, one per DPI scale.

**Implements** `MMAnimatingImageViewDelegate` to receive drag-drop image events from the scale views and update the corresponding `MCCursor` representation.

**Also defines:** `MCCursorTypeValueTransformer` — Converts a cursor identifier string to/from a human-readable name for the pop-up button.

---

#### `MCEditCapeController` (`MCEditCapeController.h` / `MCEditCapeController.m`)

Shows metadata fields for the cape itself (name, author, identifier, version). Binds directly to `MCCursorLibrary` properties via Cocoa bindings.

---

#### `MCGeneralPreferencesController` (`Preferences/MCGeneralPreferencesController.h` / `.m`)

An `NSViewController` implementing `MASPreferencesViewController`. Provides a slider or field for setting the global cursor scale multiplier. Calls `setCursorScale()` from `mousecloak`'s `scale.h`.

---

### Views

#### `MMAnimatingImageView` (`MMAnimatingImageView.h` / `MMAnimatingImageView.m`)

A custom `NSView` that:
- Displays a cursor image that may be animated (by scrolling through sprite-sheet frames using a timer).
- Accepts and provides drag-and-drop of images (`NSDraggingDestination` / `NSDraggingSource`).
- Draws a crosshair overlay at `hotSpot` when `shouldShowHotSpot` is `YES`.
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

**Protocol `MMAnimatingImageViewDelegate`** (implemented by `MCEditDetailController`):

```objc
- imageView:draggingEntered:          // Return allowed drag operation
- imageView:shouldPrepareForDragOperation: // Validate drop
- imageView:shouldPerformDragOperation:    // Confirm drop
- imageView:didAcceptDroppedImages:        // Receive dropped images
- imageView:didDragOutImage:               // Image dragged away
```

---

#### `MCCapeCellView` (`MCCapeCellView.h` / `MCCapeCellView.m`)

An `NSTableCellView` subclass for the main library table. Displays:
- `titleField` — Cape name.
- `subtitleField` — Author and version.
- `appliedImageView` — Checkmark icon shown when the cape is applied.
- `resolutionImageView` — HiDPI indicator badge.
- `collectionView` — A small `NSCollectionView` showing animated previews of cursors using `MCCapePreviewItem`.

**Also defines:** `MCHDValueTransformer` — Converts the `hiDPI` boolean to a badge image or hidden state.

---

#### `MCCapePreviewItem` (`MCCapePreviewItem.h` / `MCCapePreviewItem.m`)

An `NSCollectionViewItem` used inside `MCCapeCellView`'s collection view. Each item hosts a single `MMAnimatingImageView` to show one cursor preview.

---

#### `MCSpriteLayer` (`MCSpriteLayer.h` / `MCSpriteLayer.m`)

A `CALayer` subclass that renders a single frame of a sprite sheet by adjusting the layer's `contentsRect`. Used internally by `MMAnimatingImageView` for Core Animation–based rendering.

**Key properties:**
- `frameCount` — Total number of frames in the sprite sheet.
- `sampleIndex` — The frame currently displayed (0-based).

---

### Subclasses and Utilities

#### `MCFormatters` (`MCFormatters.h` / `MCFormatters.m`)

Two `NSFormatter` subclasses used in Interface Builder bindings:

- **`MCPointFormatter`** — Formats an `NSPoint` value (e.g., the hotspot) for display in a text field.
- **`MCSizeFormatter`** — Formats an `NSSize` value (e.g., the cursor size) for display in a text field.

---

### Categories

#### `NSFileManager+DirectoryLocations` (`NSFileManager+DirectoryLocations.h` / `.m`)

Adds convenience methods to `NSFileManager`:
- `-findOrCreateDirectory:inDomain:appendPathComponent:error:` — Finds or creates a standard search-path directory.
- `-applicationSupportDirectory` — Returns the path to `~/Library/Application Support/Mousecape/`.

Used by `MCLibraryController` to locate where cape files are stored.

---

#### `NSOrderedSet+AZSortedInsert` (`NSOrderedSet+AZSortedInsert.h` / `.m`)

Adds sorted-insertion methods to `NSOrderedSet` and `NSMutableOrderedSet`:
- `-indexForInsertingObject:sortedUsingComparator:` — Binary-search to find the correct insertion index.
- `-insertObject:sortedUsingDescriptors:` (mutable) — Insert while maintaining sort order.

Used by `MCLibraryController` to keep the `capes` ordered set alphabetically sorted.

---

## mousecloak — CLI Daemon

Located in `Mousecape/mousecloak/`. Compiled as a standalone command-line binary that is embedded inside `Mousecape.app` and invoked by the GUI via `NSTask`.

### `main.m`

Parses command-line arguments using the `GBCli` library and dispatches to the appropriate function:

| Flag | Function called | Description |
|---|---|---|
| `--apply <path>` | `applyCapeAtPath()` | Apply a `.cape` file to the system |
| `--reset` | `resetAllCursors()` | Restore default macOS cursors |
| `--create <dir>` | `createCape()` | Create a `.cape` from a directory of images |
| `--convert <file>` | `createCape(..., convert:YES)` | Convert a `.MightyMouse` file to `.cape` |
| `--dump <file>` | `dumpCursorsToFile()` | Dump currently applied system cursors to a file |
| `--export <file> -o <dir>` | `exportCape()` | Export a `.cape` to a folder of images |
| `--scale [value]` | `cursorScale()` / `setCursorScale()` | Get or set the cursor size multiplier |
| `--listen` | `listener()` | Run as a daemon, re-applying the cape on user switch |

---

### `apply.h` / `apply.m`

Contains the core cursor-registration logic:

- **`applyCapeAtPath(NSString *path)`** — Loads a `.cape` plist from disk and calls `applyCape()`.
- **`applyCape(NSDictionary *dictionary)`** — Iterates over cursors in the dictionary and calls `applyCapeForIdentifier()` for each.
- **`applyCapeForIdentifier(NSDictionary *cursor, NSString *identifier, BOOL restore)`** — Decodes image data and calls `applyCursorForIdentifier()`.
- **`applyCursorForIdentifier(frameCount, frameDuration, hotSpot, size, images, ident, repeatCount)`** — The lowest-level function. Calls the private CoreGraphics API `CGSRegisterCursorWithImages()` via `CGSGetDefaultConnection()` to register the custom cursor globally.

**Depends on:** `MCDefs.h`, `CGSInternal/CGSCursor.h`, `CGSInternal/CGSConnection.h`.

---

### `create.h` / `create.m`

Handles creation and export of capes:

- **`createCape(input, output, convert)`** — Entry point. If `convert` is `YES`, reads a `.MightyMouse` dictionary; otherwise, reads a directory of cursor folders. Calls `createCapeFromDirectory()` or `createCapeFromMightyMouse()` and writes the result to disk.
- **`createCapeFromDirectory(NSString *path)`** — Reads a folder where each sub-folder is named after a cursor identifier and contains numbered PNG frames (`0.png`, `1.png`, …). Stacks frames using `MCCursor +composeRepresentationWithFrames:`.
- **`createCapeFromMightyMouse(NSDictionary *mightyMouse, NSDictionary *metadata)`** — Converts the legacy MightyMouse plist format to the Mousecape cape dictionary format.
- **`dumpCursorsToFile(path, progress)`** — Reads the currently registered system cursors (using `CGSCopyRegisteredCursorImages`) and writes them to a new `.cape` file.
- **`exportCape(cape, destination)`** — Writes each cursor's frames as individual PNG files in sub-folders, reversing the cape format back to a directory tree.
- **`processedCapeWithIdentifier(identifier)`** — Retrieves and processes the cursor images for a single cursor identifier from the running system.

**Depends on:** `MCDefs.h`, `CGSInternal/CGSCursor.h`, `NSBitmapImageRep+ColorSpace.h`.

---

### `restore.h` / `restore.m`

- **`resetAllCursors()`** — Iterates over all default cursor identifiers and calls `restoreCursorForIdentifier()` for each.
- **`restoreCursorForIdentifier(NSString *ident)`** — Reads the backed-up image data for a cursor and re-registers the original cursor via `CGSRegisterCursorWithImages()`.
- **`restoreStringForIdentifier(NSString *identifier)`** — Returns the file path used to store the backup for a given identifier.

**Depends on:** `backup.h`, `apply.h`, `MCDefs.h`.

---

### `backup.h` / `backup.m`

- **`backupAllCursors()`** — Dumps all current system cursors to a backup folder before applying a cape, so they can be restored later.
- **`backupCursorForIdentifier(NSString *ident)`** — Reads the current CGS cursor and saves its raw data to a backup file.
- **`backupStringForIdentifier(NSString *identifier)`** — Returns the file path used to store the backup for a given identifier (`~/Library/Application Support/Mousecape/backups/<identifier>`).

---

### `listen.h` / `listen.m`

- **`listener()`** — A blocking function that runs a `CFRunLoop`. It registers for `kCGSNotificationUserSessionDidBecomeActive` CoreGraphics session notifications. Each time a user session becomes active (login or fast-user switch), it reads the currently applied cape path from preferences and calls `applyCapeAtPath()` to re-apply it.
- **`appliedCapePathForUser(NSString *user)`** — Returns the path to the `.cape` file that was last applied for a given user.

**Depends on:** `apply.h`, `MCPrefs.h`, `CGSInternal/CGSSession.h`, `CGSInternal/CGSNotifications.h`.

---

### `scale.h` / `scale.m`

- **`cursorScale()`** — Returns the current cursor scale multiplier from the system.
- **`defaultCursorScale()`** — Returns the default (1.0) scale.
- **`setCursorScale(float scale)`** — Writes the desired scale to preferences and applies it to the current CGS connection.

---

### `MCDefs.h` / `MCDefs.m`

Global constants and utilities shared across both the main app and `mousecloak`:

- **Logging macros:** `MMLog(format, ...)` / `MMOut(format, ...)` for stdout output.
- **ANSI colour macros:** `RED`, `GREEN`, `BOLD`, etc. for coloured CLI output.
- **Dictionary key constants:** `MCCursorDictionaryFrameCountKey`, `MCCursorDictionaryHotSpotXKey`, etc. — keys used in `.cape` plist files.
- **Error codes:** `MCErrorCode` enum with values such as `MCErrorInvalidCapeCode`.
- **Version constants:** `MCCursorCreatorVersion`, `MCCursorParserVersion`.
- **`cursorMap()`** — Returns the mapping from cursor identifier to system cursor type.
- **`nameForCursorIdentifier()` / `cursorIdentifierForName()`** — Bidirectional lookup between reverse-DNS identifiers and human-readable names.
- **`defaultCursors[]`** — Array of all standard macOS cursor identifiers.

---

### `MCPrefs.h` / `MCPrefs.m`

Thin wrapper around `NSUserDefaults` for persisting settings:
- The path of the currently applied cape (per user).
- The cursor scale multiplier.

---

### `NSBitmapImageRep+ColorSpace` (`NSBitmapImageRep+ColorSpace.h` / `.m`)

A category on `NSBitmapImageRep` that adds color-space conversion utilities. Used in `create.m` when reading and compositing cursor images to ensure consistent color representation.

---

### `NSCursor_Private.h`

Declares private `NSCursor` methods and constants not in the public SDK headers. Used when the app needs to interact with system cursor identifiers.

---

## mousecloakHelper — Background Daemon

Located in `Mousecape/mousecloakHelper/`.

### `main.m`

The entire helper daemon is a single file:

```objc
int main(int argc, char * argv[]) {
    @autoreleasepool {
        listener();
        return EXIT_SUCCESS;
    }
}
```

It immediately calls `listener()` (from `listen.h`, shared with `mousecloak`) and blocks indefinitely. The daemon is registered as a **login item** via `SMLoginItemSetEnabled` from the main app. macOS will launch it at login and after user switches, keeping cursors applied persistently.

**Bundle ID:** `com.alexzielenski.mousecloakhelper`

---

## External Libraries

Located in `Mousecape/Mousecape/external/`.

| Library | Purpose |
|---|---|
| **Sparkle** | Automatic over-the-air updates. Configured with `SUFeedURL` in `Mousecape-Info.plist` pointing to `appcast_signed.xml` on GitHub (`appcast.xml` is the unsigned local copy in the repo). |
| **MASPreferences** | Provides the tabbed preferences window (`MASPreferencesWindowController`). Used by `MCAppDelegate` to host `MCGeneralPreferencesController`. |
| **BTRKit** | Custom `NSScrollView`/`NSClipView` subclasses (`BTRScrollView`, `BTRClipView`) for improved scrolling UX in the library list. |
| **Rebel** | Another scroll view implementation (`RBLScrollView`, `RBLClipView`). Also provides `NSColor+RBLCGColorAdditions`. |
| **DTScrollView** | Additional third-party scroll view. |

**GBCli** (in `mousecloak/vendor/GBCli/`):

| Class | Purpose |
|---|---|
| `GBSettings` | Key-value store for parsed CLI arguments |
| `GBCommandLineParser` | Tokenises `argv` and fires a callback block per option |
| `GBOptionsHelper` | Registers option definitions and prints formatted help text |

---

## Private CoreGraphics Headers (CGSInternal)

Located in `Mousecape/mousecloak/CGSInternal/`. These are reverse-engineered headers for private Apple frameworks. **They are not part of any public SDK.**

| Header | Contents |
|---|---|
| `CGSConnection.h` | `CGSConnectionID` type; `CGSGetDefaultConnection()` |
| `CGSCursor.h` | Cursor registration APIs: `CGSRegisterCursorWithImages`, `CGSCopyRegisteredCursorImages`, `CGSSetRegisteredCursor`, `CoreCursorUnregisterAll`, etc. |
| `CGSSession.h` | Session notification types; used by `listen.m` to detect user switches |
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

**Cursor identifiers** follow the reverse-DNS pattern `com.apple.coregraphics.<Name>` for system cursors or `com.apple.cursor.<N>` for indexed cursors. The full list is defined in `MCDefs.m` as `defaultCursors[]`.

---

## Component Relationships Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                          Mousecape.app                                 │
│                                                                        │
│  main.m ──► MCAppDelegate                                              │
│               │                                                        │
│               ├── MCLibraryWindowController (Library.xib)             │
│               │       │                                                │
│               │       └── MCLibraryViewController                     │
│               │               │                                        │
│               │               └── MCLibraryController ◄──── NSUserDefaults
│               │                       │  (business logic)             │
│               │                       │                                │
│               │                       ├── MCCursorLibrary[] ◄── .cape files
│               │                       │       └── MCCursor[]          │
│               │                       │                                │
│               │                       └── (invokes mousecloak binary) │
│               │                                                        │
│               ├── MCEditWindowController (Edit.xib)                   │
│               │       │                                                │
│               │       ├── MCEditListController  ──► MCCursorLibrary   │
│               │       ├── MCEditDetailController ──► MCCursor         │
│               │       │       └── MMAnimatingImageView × 4 scales     │
│               │       └── MCEditCapeController  ──► MCCursorLibrary   │
│               │                                                        │
│               └── MASPreferencesWindowController                      │
│                       └── MCGeneralPreferencesController               │
│                                                                        │
└───────────────────────────────┬────────────────────────────────────────┘
                                │ NSTask --apply / --reset / --scale
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                           mousecloak (CLI)                             │
│                                                                        │
│  main.m (GBCli argument parsing)                                       │
│    │                                                                   │
│    ├── apply.m ──────────────────────────────────────────────────┐    │
│    │   applyCapeAtPath()                                          │    │
│    │   applyCape()                                                │    │
│    │   applyCapeForIdentifier()                                   │    │
│    │   applyCursorForIdentifier() ──► CGSRegisterCursorWithImages │    │
│    │                                  (private CoreGraphics API)  │    │
│    ├── create.m                                                   │    │
│    │   createCape() / createCapeFromDirectory()                   │    │
│    │   dumpCursorsToFile() ──► CGSCopyRegisteredCursorImages      │    │
│    │   exportCape()                                               │    │
│    ├── restore.m ──► backup.m ──► apply.m                         │    │
│    │   resetAllCursors()                                          │    │
│    ├── scale.m ──► MCPrefs.m                                      │    │
│    └── listen.m ──► CGSNotifications ──► applyCapeAtPath()        │    │
│                                                                   │    │
│  CGSInternal/ (private headers) ◄─────────────────────────────────┘   │
│  MCDefs.m (cursor map, constants)                                      │
│  MCPrefs.m (NSUserDefaults)                                            │
└────────────────────────────────────────────────────────────────────────┘
                                │ SMLoginItemSetEnabled
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                      mousecloakHelper (daemon)                         │
│                                                                        │
│  main.m ──► listener() ──► (blocks on CFRunLoop)                      │
│                 │                                                      │
│                 └── On user-switch notification:                       │
│                         applyCapeAtPath(currentCapePath)               │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Application Startup and Main Flow

### 1. App Launch

1. macOS executes `Mousecape.app/Contents/MacOS/Mousecape`.
2. `main.m` calls `NSApplicationMain()`.
3. Cocoa loads `MainMenu.xib`, creating the menu bar and instantiating `MCAppDelegate`.
4. `MCAppDelegate -applicationWillFinishLaunching:` creates `MCLibraryWindowController` (from `Library.xib`) and calls `loadWindow`.
5. `MCLibraryWindowController` loads `MCLibraryViewController`.
6. `MCLibraryViewController` creates `MCLibraryController` (passing the library directory URL).
7. `MCLibraryController` scans `~/Library/Application Support/Mousecape/capes/` for `.cape` files, deserializes each into an `MCCursorLibrary`, and populates the `capes` ordered set.
8. `MCAppDelegate -applicationDidFinishLaunching:` shows the library window.
9. If a cape was previously applied (stored in `NSUserDefaults`), `MCLibraryController -applyCape:` is called to reapply it.

### 2. Applying a Cape

1. The user selects a cape in `MCLibraryViewController` and chooses "Apply" (from the context menu or toolbar).
2. `MCLibraryViewController` calls `MCLibraryController -applyCape:`.
3. `MCLibraryController` serializes the `MCCursorLibrary` to a temporary `.cape` file.
4. It launches the `mousecloak` binary (via `NSTask`) with the `--apply <path>` flag.
5. `mousecloak` calls `applyCapeAtPath()` → `applyCape()` → `applyCapeForIdentifier()` → `applyCursorForIdentifier()`.
6. `CGSRegisterCursorWithImages()` registers each cursor image in the window server globally.
7. The cursor changes are immediately visible system-wide.
8. `MCLibraryController` updates `appliedCape` and saves the cape path to `NSUserDefaults`.

### 3. Editing a Cape

1. The user double-clicks a cape (or chooses "Edit" from the context menu).
2. `MCLibraryViewController -editCape:` opens `MCEditWindowController`.
3. `MCEditWindowController` sets `cursorLibrary` and propagates it to all three sub-controllers.
4. The user selects a cursor in `MCEditListController`; the detail panel switches to `MCEditDetailController`.
5. The user drags a PNG onto one of the four `MMAnimatingImageView` scale wells.
6. `MMAnimatingImageViewDelegate` (implemented by `MCEditDetailController`) fires `-imageView:didAcceptDroppedImages:`.
7. `MCEditDetailController` calls `-setRepresentation:forScale:` on the `MCCursor`.
8. `MCCursorLibrary` marks itself as dirty and posts `MCLibraryWillSaveNotificationName`.
9. The user saves (⌘S); `MCCursorLibrary -save` writes the plist to `fileURL`.

### 4. Creating a Cape from Scratch

1. User presses ⌘N (or chooses File → New).
2. `MCAppDelegate -newDocument:` calls `MCLibraryController -importCape:` with a new empty `MCCursorLibrary`.
3. The library is added to the capes set and a backing `.cape` file is created on disk.
4. The user opens the edit window, adds cursors, drags in images, and saves.

### 5. Helper Daemon (mousecloakHelper)

1. On first launch, the user chooses **Mousecape → Install Helper Tool**.
2. `MCAppDelegate -toggleInstall:` calls `SMLoginItemSetEnabled(CFSTR("com.alexzielenski.mousecloakhelper"), true)`.
3. macOS registers the helper as a per-user launchd agent.
4. `mousecloakHelper` starts and calls `listener()`, blocking on a `CFRunLoop`.
5. Whenever the user logs in or fast-user-switches, CoreGraphics fires `kCGSNotificationUserSessionDidBecomeActive`.
6. `listener()` reads the last applied cape path from `NSUserDefaults` and calls `applyCapeAtPath()`.
7. The custom cursors are restored without any user interaction.
