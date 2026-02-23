// create.swift
// Mousecape
//
// Swift replacement for create.h / create.m

import AppKit
import Foundation

// MARK: - createCape

func createCape(_ input: String, output: String, convert: Bool) -> NSError? {
    let cape: [String: Any]?
    if convert {
        cape = createCapeFromMightyMouse(
            NSDictionary(contentsOfFile: input) as? [String: Any],
            metadata: nil)
    } else {
        cape = createCapeFromDirectory(input)
    }

    guard let capeDict = cape else {
        let reason = convert
            ? NSLocalizedString("Unable to create a cape from the file specified.", comment: "")
            : NSLocalizedString("Unable to create a cape from the directory specified.", comment: "")
        return NSError(
            domain: MCErrorDomain,
            code: MCErrorCode.invalidCape.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Failed to create cape file", comment: ""),
                NSLocalizedFailureReasonErrorKey: reason,
            ])
    }

    guard (capeDict as NSDictionary).write(toFile: output, atomically: false) else {
        return NSError(
            domain: MCErrorDomain,
            code: MCErrorCode.writeFail.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Failed to create cape file", comment: ""),
                NSLocalizedFailureReasonErrorKey: String(format:
                    NSLocalizedString("The destination, %@, is not writable.", comment: ""),
                    output),
            ])
    }
    return nil
}

// MARK: - createCapeFromDirectory

func createCapeFromDirectory(_ path: String) -> [String: Any]? {
    let manager = FileManager.default
    var isDir: ObjCBool = false
    guard manager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }

    guard let contents = try? manager.contentsOfDirectory(atPath: path) else { return nil }

    var dictionary: [String: Any] = [
        MCCursorDictionaryVersionKey:        MCCursorCreatorVersion,
        MCCursorDictionaryMinimumVersionKey: MCCursorParserVersion,
    ]

    MMLog("\u{001B}[1mEnter metadata for cape:\u{001B}[0m")
    let author     = MMGet("Author")
    let identifier = MMGet("Identifier")
    let name       = MMGet("Cape Name")
    MMOut("Cape Version: ")
    let version    = Double(readLine() ?? "") ?? 0.0
    let hidpiStr   = MMGet("HiDPI? (y/n)")

    let hiDPI = hidpiStr == "y"

    dictionary[MCCursorDictionaryAuthorKey]      = author
    dictionary[MCCursorDictionaryIdentifierKey]  = identifier
    dictionary[MCCursorDictionaryCapeNameKey]    = name
    dictionary[MCCursorDictionaryCapeVersionKey] = version
    dictionary[MCCursorDictionaryCloudKey]       = false
    dictionary[MCCursorDictionaryHiDPIKey]       = hiDPI

    var cursors: [String: Any] = [:]

    for subpath in contents {
        let fullPath = (path as NSString).appendingPathComponent(subpath)
        var subIsDir: ObjCBool = false
        manager.fileExists(atPath: fullPath, isDirectory: &subIsDir)
        guard subIsDir.boolValue else { continue }

        let ident = subpath
        var data: [String: Any] = [:]

        print("\u{001B}[1mNeed metadata for \(ident).\u{001B}[0m", terminator: "")
        MMOut("X Hotspot: ")
        let hotX = Double(readLine() ?? "") ?? 0.0
        MMOut("Y Hotspot: ")
        let hotY = Double(readLine() ?? "") ?? 0.0
        MMOut("Points Wide: ")
        let pW = Double(readLine() ?? "") ?? 0.0
        MMOut("Points High: ")
        let pH = Double(readLine() ?? "") ?? 0.0
        MMOut("Frame Count: ")
        let fC = Int(readLine() ?? "") ?? 1
        MMOut("Frame Duration: ")
        let fD = Double(readLine() ?? "") ?? 1.0

        var representations: [Data] = []
        if let repNames = try? manager.contentsOfDirectory(atPath: fullPath) {
            for rep in repNames {
                let repPath = (fullPath as NSString).appendingPathComponent(rep)
                var repIsDir: ObjCBool = false
                manager.fileExists(atPath: repPath, isDirectory: &repIsDir)
                guard !repIsDir.boolValue, rep != ".DS_Store" else { continue }
                guard let repData = FileManager.default.contents(atPath: repPath),
                      let image = NSBitmapImageRep(data: repData),
                      let pngData = image.ensuredSRGBSpace.tiffRepresentation(using: .lzw, factor: 1.0)
                else { continue }
                representations.append(pngData)
            }
        }

        data[MCCursorDictionaryHotSpotXKey]        = hotX
        data[MCCursorDictionaryHotSpotYKey]        = hotY
        data[MCCursorDictionaryPointsWideKey]      = pW
        data[MCCursorDictionaryPointsHighKey]      = pH
        data[MCCursorDictionaryFrameCountKey]      = fC
        data[MCCursorDictionaryFrameDuratiomKey]   = fD
        data[MCCursorDictionaryRepresentationsKey] = representations
        cursors[ident] = data
    }

    guard !cursors.isEmpty else { return nil }
    dictionary[MCCursorDictionaryCursorsKey] = cursors
    return dictionary
}

// MARK: - createCapeFromMightyMouse

func createCapeFromMightyMouse(
    _ mightyMouse: [String: Any]?,
    metadata: [String: Any]?
) -> [String: Any]? {
    guard let mightyMouse = mightyMouse else { return nil }

    guard let cursors    = mightyMouse["Cursors"] as? [String: Any],
          let global     = cursors["Global"] as? [String: Any],
          let cursorData = cursors["Cursor Data"] as? [String: Any],
          let identifiers = global["Identifiers"] as? [String: Any] else {
        MMLog("\u{001B}[1m\u{001B}[31mMighty Mouse format either invalid or unrecognized.\u{001B}[0m")
        return nil
    }

    var convertedCursors: [String: Any] = [:]

    for (key, value) in identifiers {
        MMLog("Converting cursor: \(key)")
        guard let info = value as? [String: Any],
              let customKey = info["Custom Key"] as? String,
              let data = cursorData[customKey] as? [String: Any] else { continue }

        guard let bpp     = data["BitsPerPixel"] as? NSNumber,
              let bps     = data["BitsPerSample"] as? NSNumber,
              let bpr     = data["BytesPerRow"] as? NSNumber,
              let rawData = data["CursorData"] as? Data,
              let spp     = data["SamplesPerPixel"] as? NSNumber,
              let fc      = data["FrameCount"] as? NSNumber,
              let fd      = data["FrameDuration"] as? NSNumber,
              let hotX    = data["HotspotX"] as? NSNumber,
              let hotY    = data["HotspotY"] as? NSNumber,
              let wide    = data["PixelsWide"] as? NSNumber,
              let high    = data["PixelsHigh"] as? NSNumber else { continue }

        let bytes = (rawData as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        var mutablePtr: UnsafeMutablePointer<UInt8>? = UnsafeMutablePointer(mutating: bytes)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: &mutablePtr,
            pixelsWide: wide.intValue,
            pixelsHigh: high.intValue * fc.intValue,
            bitsPerSample: bps.intValue,
            samplesPerPixel: spp.intValue,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bitmapFormat: NSBitmapImageRep.Format(rawValue:
                NSBitmapImageRep.Format.alphaFirst.rawValue |
                UInt(CGBitmapInfo.byteOrder32Big.rawValue)),
            bytesPerRow: bpr.intValue,
            bitsPerPixel: bpp.intValue) else { continue }

        var currentCursor: [String: Any] = [:]
        if let tiff = rep.ensuredSRGBSpace.tiffRepresentation(using: .lzw, factor: 1.0) {
            currentCursor[MCCursorDictionaryRepresentationsKey] = [tiff]
        }
        currentCursor[MCCursorDictionaryPointsWideKey]    = wide
        currentCursor[MCCursorDictionaryPointsHighKey]    = high
        currentCursor[MCCursorDictionaryHotSpotXKey]      = hotX
        currentCursor[MCCursorDictionaryHotSpotYKey]      = hotY
        currentCursor[MCCursorDictionaryFrameCountKey]    = fc
        currentCursor[MCCursorDictionaryFrameDuratiomKey] = fd
        convertedCursors[key] = currentCursor
    }

    guard !convertedCursors.isEmpty else {
        MMLog("\u{001B}[1m\u{001B}[31mNo cursors to convert in file.\u{001B}[0m")
        return nil
    }

    var totalDict: [String: Any] = [
        MCCursorDictionaryCursorsKey:        convertedCursors,
        MCCursorDictionaryVersionKey:        MCCursorCreatorVersion,
        MCCursorDictionaryMinimumVersionKey: MCCursorParserVersion,
        MCCursorDictionaryHiDPIKey:          false,
        MCCursorDictionaryCloudKey:          false,
    ]

    MMLog("\u{001B}[1mEnter metadata for cape:\u{001B}[0m")
    let author     = metadata?["author"]     as? String ?? MMGet("Author")
    let identifier = metadata?["identifier"] as? String ?? MMGet("Identifier")
    let name       = metadata?["name"]       as? String ?? MMGet("Cape Name")

    let version: Double
    if let v = metadata?["version"] as? NSNumber {
        version = v.doubleValue
    } else {
        MMOut("Cape Version: ")
        version = Double(readLine() ?? "") ?? 0.0
    }

    totalDict[MCCursorDictionaryAuthorKey]      = author
    totalDict[MCCursorDictionaryCapeNameKey]    = name
    totalDict[MCCursorDictionaryCapeVersionKey] = version
    totalDict[MCCursorDictionaryIdentifierKey]  = identifier

    return totalDict
}

// MARK: - processedCapeWithIdentifier

func processedCapeWithIdentifier(_ identifier: String) -> [String: Any]? {
    guard var dict = capeWithIdentifier(identifier) else { return nil }
    guard let repsRaw = dict[MCCursorDictionaryRepresentationsKey] else { return nil }
    let repsArray = repsRaw as! CFArray

    var pngs: [Data] = []
    for i in 0..<CFArrayGetCount(repsArray) {
        let raw = CFArrayGetValueAtIndex(repsArray, i)
        let img = Unmanaged<CGImage>.fromOpaque(raw!).takeUnretainedValue()
        let rep = NSBitmapImageRep(cgImage: img)
        if let data = pngDataForImage(rep.ensuredSRGBSpace) {
            pngs.append(data)
        }
    }

    dict[MCCursorDictionaryRepresentationsKey] = pngs
    return dict
}

// MARK: - dumpCursorsToFile

@discardableResult
func dumpCursorsToFile(_ path: String, progress: ((Int, Int) -> Bool)?) -> Bool {
    MMLog("Dumping cursors...")

    var originalScale: Float = 1.0
    CGSGetCursorScale(CGSMainConnectionID(), &originalScale)
    CGSSetCursorScale(CGSMainConnectionID(), 16.0)
    CGSHideCursor(CGSMainConnectionID())

    let total = defaultCursors.count + 45
    var current = 0
    var cursors: [String: Any] = [:]

    for (i, key) in defaultCursors.enumerated() {
        current = i
        if let prog = progress, !prog(current, total) { return false }
        MMLog("Gathering data for \(key)")
        if let cape = processedCapeWithIdentifier(key) {
            cursors[key] = cape
        }
    }

    for x in 0..<45 {
        current = defaultCursors.count + x
        if let prog = progress, !prog(current, total) { return false }
        let key = "com.apple.cursor.\(x)"
        CoreCursorSet(CGSMainConnectionID(), Int32(x))
        guard let cape = processedCapeWithIdentifier(key) else { continue }
        MMLog("Gathering data for \(key)")
        cursors[key] = cape
    }

    progress?(total, total)

    let cape: [String: Any] = [
        MCCursorDictionaryAuthorKey:      "Apple, Inc.",
        MCCursorDictionaryCapeNameKey:    "Cursor Dump",
        MCCursorDictionaryCapeVersionKey: 1.0,
        MCCursorDictionaryCloudKey:       false,
        MCCursorDictionaryCursorsKey:     cursors,
        MCCursorDictionaryHiDPIKey:       true,
        MCCursorDictionaryIdentifierKey:  "com.alexzielenski.mousecape.dump",
        MCCursorDictionaryVersionKey:     MCCursorCreatorVersion,
        MCCursorDictionaryMinimumVersionKey: MCCursorParserVersion,
    ]

    CGSSetCursorScale(CGSMainConnectionID(), originalScale)
    CGSShowCursor(CGSMainConnectionID())

    return (cape as NSDictionary).write(toFile: path, atomically: false)
}

// MARK: - dumpCursorsToFolder

@discardableResult
func dumpCursorsToFolder(_ path: String, progress: ((Int, Int) -> Bool)?) -> Bool {
    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    MMLog("Dumping cursors...")

    var originalScale: Float = 1.0
    CGSGetCursorScale(CGSMainConnectionID(), &originalScale)
    CGSSetCursorScale(CGSMainConnectionID(), 16.0)
    CGSHideCursor(CGSMainConnectionID())

    let total = defaultCursors.count + 45
    var current = 0

    for (i, key) in defaultCursors.enumerated() {
        current = i
        if let prog = progress, !prog(current, total) { return false }
        MMLog("Gathering data for \(key)")
        if let cape = processedCapeWithIdentifier(key),
           let reps = cape[MCCursorDictionaryRepresentationsKey] as? [Data],
           let last = reps.last {
            let dest = ((path as NSString).appendingPathComponent(key) as NSString)
                .appendingPathExtension("png") ?? "\(path)/\(key).png"
            last.write(toFile: dest, atomically: false)
        }
    }

    for x in 0..<45 {
        current = defaultCursors.count + x
        if let prog = progress, !prog(current, total) { return false }
        let key = "com.apple.cursor.\(x)"
        CoreCursorSet(CGSMainConnectionID(), Int32(x))
        guard let cape = processedCapeWithIdentifier(key),
              let reps = cape[MCCursorDictionaryRepresentationsKey] as? [Data],
              let last = reps.last else { continue }
        MMLog("Gathering data for \(key)")
        let dest = ((path as NSString).appendingPathComponent(key) as NSString)
            .appendingPathExtension("png") ?? "\(path)/\(key).png"
        last.write(toFile: dest, atomically: false)
    }

    progress?(total, total)

    CGSSetCursorScale(CGSMainConnectionID(), originalScale)
    CGSShowCursor(CGSMainConnectionID())
    return true
}

// MARK: - exportCape

func exportCape(_ cape: [String: Any], destination: String) {
    let manager = FileManager.default
    try? manager.createDirectory(atPath: destination, withIntermediateDirectories: true)

    guard let cursors = cape[MCCursorDictionaryCursorsKey] as? [String: Any] else { return }
    for (key, value) in cursors {
        guard let cursorDict = value as? [String: Any],
              let reps = cursorDict[MCCursorDictionaryRepresentationsKey] as? [Data] else { continue }
        for (idx, data) in reps.enumerated() {
            let filename = "\(key)_\(idx).png"
            let destPath = (destination as NSString).appendingPathComponent(filename)
            data.write(toFile: destPath, atomically: false)
        }
    }
}
