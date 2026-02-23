// MCDefs.swift
// Mousecape
//
// Swift replacement for MCDefs.h / MCDefs.m

import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - stdout helpers

func MMOut(_ message: String) {
    print(message, terminator: "")
}

func MMLog(_ message: String) {
    print(message)
}

// MARK: - Default cursors

let defaultCursors: [String] = [
    "com.apple.coregraphics.Arrow",
    "com.apple.coregraphics.IBeam",
    "com.apple.coregraphics.IBeamXOR",
    "com.apple.coregraphics.Alias",
    "com.apple.coregraphics.Copy",
    "com.apple.coregraphics.Move",
    "com.apple.coregraphics.ArrowCtx",
    "com.apple.coregraphics.Wait",
    "com.apple.coregraphics.Empty",
]

// MARK: - Error domain and codes

let MCErrorDomain = "com.alexzielenski.mousecape.error"

@objc enum MCErrorCode: Int {
    case invalidCape = -1
    case writeFail = -2
    case invalidFormat = -100
    case multipleCursorIdentifiers = -101
}

// MARK: - Version / dictionary key constants

let MCCursorCreatorVersion: CGFloat = 2.0
let MCCursorParserVersion: CGFloat  = 2.0

let MCCursorDictionaryMinimumVersionKey: String  = "MinimumVersion"
let MCCursorDictionaryVersionKey: String         = "Version"
let MCCursorDictionaryCursorsKey: String         = "Cursors"
let MCCursorDictionaryAuthorKey: String          = "Author"
let MCCursorDictionaryCloudKey: String           = "Cloud"
let MCCursorDictionaryHiDPIKey: String           = "HiDPI"
let MCCursorDictionaryIdentifierKey: String      = "Identifier"
let MCCursorDictionaryCapeNameKey: String        = "CapeName"
let MCCursorDictionaryCapeVersionKey: String     = "CapeVersion"

let MCCursorDictionaryFrameCountKey: String      = "FrameCount"
let MCCursorDictionaryFrameDuratiomKey: String   = "FrameDuration"
let MCCursorDictionaryHotSpotXKey: String        = "HotSpotX"
let MCCursorDictionaryHotSpotYKey: String        = "HotSpotY"
let MCCursorDictionaryPointsWideKey: String      = "PointsWide"
let MCCursorDictionaryPointsHighKey: String      = "PointsHigh"
let MCCursorDictionaryRepresentationsKey: String = "Representations"

// MARK: - Cursor name map

let cursorNameMap: [String: String] = {
    return [
        "com.apple.cursor.23":            "Resize N-S",
        "com.apple.cursor.9":             "Camera 2",
        "com.apple.cursor.26":            "IBeam H.",
        "com.apple.cursor.29":            "Window NE",
        "com.apple.cursor.4":             "Busy",
        "com.apple.coregraphics.ArrowCtx":"Ctx Arrow",
        "com.apple.cursor.12":            "Open",
        "com.apple.cursor.32":            "Window N-S",
        "com.apple.cursor.35":            "Window SE",
        "com.apple.cursor.15":            "Counting Down",
        "com.apple.cursor.38":            "Window W",
        "com.apple.cursor.18":            "Resize E",
        "com.apple.cursor.41":            "Cell",
        "com.apple.cursor.21":            "Resize N",
        "com.apple.cursor.5":             "Copy Drag",
        "com.apple.cursor.24":            "Ctx Menu",
        "com.apple.cursor.27":            "Window E",
        "com.apple.cursor.30":            "Window NE-SW",
        "com.apple.cursor.10":            "Camera",
        "com.apple.cursor.33":            "Window NW",
        "com.apple.cursor.13":            "Pointing",
        "com.apple.coregraphics.IBeamXOR":"IBeamXOR",
        "com.apple.coregraphics.Copy":    "Copy",
        "com.apple.coregraphics.Arrow":   "Arrow",
        "com.apple.cursor.16":            "Counting Up/Down",
        "com.apple.cursor.36":            "Window S",
        "com.apple.cursor.39":            "Resize Square",
        "com.apple.cursor.19":            "Resize W-E",
        "com.apple.cursor.42":            "Zoom In",
        "com.apple.cursor.22":            "Resize S",
        "com.apple.coregraphics.IBeam":   "IBeam",
        "com.apple.coregraphics.Move":    "Move",
        "com.apple.cursor.7":             "Crosshair",
        "com.apple.cursor.25":            "Poof",
        "com.apple.coregraphics.Wait":    "Wait",
        "com.apple.cursor.2":             "Link",
        "com.apple.cursor.28":            "Window E-W",
        "com.apple.cursor.31":            "Window N",
        "com.apple.cursor.11":            "Closed",
        "com.apple.coregraphics.Alias":   "Alias",
        "com.apple.coregraphics.Empty":   "Empty",
        "com.apple.cursor.14":            "Counting Up",
        "com.apple.cursor.34":            "Window NW-SE",
        "com.apple.cursor.8":             "Crosshair 2",
        "com.apple.cursor.37":            "Window SW",
        "com.apple.cursor.17":            "Resize W",
        "com.apple.cursor.40":            "Help",
        "com.apple.cursor.3":             "Forbidden",
        "com.apple.cursor.20":            "Cell XOR",
        "com.apple.cursor.43":            "Zoom Out",
    ]
}()

// MARK: - Name/identifier lookup

func nameForCursorIdentifier(_ identifier: String) -> String {
    return cursorNameMap[identifier] ?? "Unknown"
}

func cursorIdentifierForName(_ name: String) -> String {
    if let key = cursorNameMap.first(where: { $0.value == name })?.key {
        return key
    }
    return Foundation.UUID().uuidString
}

// MARK: - UUID helper

func UUID() -> String {
    return Foundation.UUID().uuidString
}

// MARK: - User input

func MMGet(_ prompt: String) -> String {
    MMOut("\(prompt): ")
    return readLine() ?? ""
}

// MARK: - Image utilities

func CGImageWriteToFile(_ image: CGImage, _ path: CFString) {
    guard let url = CFURLCreateWithFileSystemPath(nil, path, .posixPathStyle, false) else { return }
    guard let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
        MMLog("Failed to create image destination for \(path)")
        return
    }
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        MMLog("Failed to write image to \(path)")
    }
}

func pngDataForImage(_ image: Any) -> Data? {
    if let rep = image as? NSBitmapImageRep {
        return rep.tiffRepresentation(using: .lzw, factor: 1.0)
    }
    // CGImage
    let cgImage = image as! CGImage
    let mutableData = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
        return nil
    }
    CGImageDestinationAddImage(dest, cgImage, nil)
    CGImageDestinationFinalize(dest)
    return mutableData as Data
}

// MARK: - CGS cursor registration

/// Returns whether a named cursor is registered in the CGS connection.
@discardableResult
func MCIsCursorRegistered(_ cid: CGSConnectionID, _ cursorName: String, _ registered: inout Bool) -> CGError {
    return cursorName.withCString { cStr in
        var size = 0
        let err = CGSGetRegisteredCursorDataSize(cid, UnsafeMutablePointer(mutating: cStr), &size)
        registered = (err == 0) && (size > 0)
        return err
    }
}

/// Returns a cursor dictionary for a registered cursor identifier, or nil if not registered.
func capeWithIdentifier(_ identifier: String) -> [String: Any]? {
    var registered = false
    MCIsCursorRegistered(CGSMainConnectionID(), identifier, &registered)
    guard registered else { return nil }

    var frameCount = 0
    var frameDuration: CGFloat = 0
    var hotSpot = CGPoint.zero
    var size = CGSize.zero
    var representations: CFArray? = nil
    var error: CGError = 0

    identifier.withCString { cStr in
        if !identifier.hasPrefix("com.apple.cursor") {
            error = CGSCopyRegisteredCursorImages(
                CGSMainConnectionID(),
                UnsafeMutablePointer(mutating: cStr),
                &size, &hotSpot, &frameCount, &frameDuration, &representations)
        } else {
            let cursorID = Int32((identifier as NSString).pathExtension) ?? 0
            error = CoreCursorCopyImages(
                CGSMainConnectionID(),
                cursorID, &representations,
                &size, &hotSpot, &frameCount, &frameDuration)
        }
    }

    guard error == 0,
          let reps = representations,
          CFArrayGetCount(reps) > 0 else { return nil }

    return [
        MCCursorDictionaryFrameCountKey:      frameCount,
        MCCursorDictionaryFrameDuratiomKey:   frameDuration,
        MCCursorDictionaryHotSpotXKey:        hotSpot.x,
        MCCursorDictionaryHotSpotYKey:        hotSpot.y,
        MCCursorDictionaryPointsWideKey:      size.width,
        MCCursorDictionaryPointsHighKey:      size.height,
        MCCursorDictionaryRepresentationsKey: reps as NSArray,
    ]
}

// MARK: - Pointer cursor check

/// Returns true if the identifier corresponds to a "pointer"-style cursor.
func MCCursorIsPointer(_ identifier: String) -> Bool {
    struct Statics {
        static let pointers: Set<String> = {
            let names = ["Alias","Arrow","Busy","Closed","Copy Drag","Counting Down",
                         "Counting Up","Counting Up/Down","Ctx Menu","Forbidden",
                         "Link","Move","Open","Pointing","Poof","Wait","Zoom In","Zoom Out"]
            var result = Set<String>()
            for name in names {
                if let key = cursorNameMap.first(where: { $0.value == name })?.key {
                    result.insert(key)
                }
            }
            return result
        }()
    }
    return Statics.pointers.contains(identifier)
}
