// apply.swift
// Mousecape
//
// Swift replacement for apply.h / apply.m

import AppKit

// MARK: - Apply single cursor

@discardableResult
func applyCursorForIdentifier(
    frameCount: Int,
    frameDuration: CGFloat,
    hotSpot: CGPoint,
    size: CGSize,
    images: [Any],
    ident: String,
    repeatCount: Int
) -> Bool {
    guard frameCount >= 1 && frameCount <= 24 else {
        MMLog("\u{001B}[1m\u{001B}[31mFrame count of \(ident) out of range [1...24]")
        return false
    }

    var seed: Int32 = 0
    var err: CGError = 0
    ident.withCString { cStr in
        err = CGSRegisterCursorWithImages(
            CGSMainConnectionID(),
            UnsafeMutablePointer(mutating: cStr),
            true,
            true,
            size,
            hotSpot,
            frameCount,
            frameDuration,
            images as CFArray,
            &seed)
    }
    return err == kCGErrorSuccess
}

// MARK: - Apply cape for identifier

@discardableResult
func applyCapeForIdentifier(_ cursor: [String: Any]?, identifier: String, restore: Bool) -> Bool {
    guard let cursor = cursor else {
        NSLog("bad seed")
        return false
    }

    let lefty   = MCFlag(MCPreferencesHandednessKey)
    let pointer = MCCursorIsPointer(identifier)

    guard let frameCountNum    = cursor[MCCursorDictionaryFrameCountKey] as? NSNumber,
          let frameDurationNum = cursor[MCCursorDictionaryFrameDuratiomKey] as? NSNumber else {
        return false
    }

    var hotSpot = CGPoint(
        x: (cursor[MCCursorDictionaryHotSpotXKey] as? NSNumber)?.doubleValue ?? 0,
        y: (cursor[MCCursorDictionaryHotSpotYKey] as? NSNumber)?.doubleValue ?? 0)
    let size = CGSize(
        width:  (cursor[MCCursorDictionaryPointsWideKey] as? NSNumber)?.doubleValue ?? 0,
        height: (cursor[MCCursorDictionaryPointsHighKey] as? NSNumber)?.doubleValue ?? 0)

    guard let reps = cursor[MCCursorDictionaryRepresentationsKey] as? [Any] else { return false }
    var images: [Any] = []

    if lefty && !restore && pointer {
        MMLog("Lefty mode for \(identifier)")
        hotSpot.x = size.width - hotSpot.x - 1
    }

    for object in reps {
        let typeID = CFGetTypeID(object as CFTypeRef)
        var rep: NSBitmapImageRep?
        if typeID == CGImage.typeID {
            rep = NSBitmapImageRep(cgImage: object as! CGImage)
        } else if let data = object as? Data {
            rep = NSBitmapImageRep(data: data)
        }
        guard let bitmapRep = rep?.retaggedSRGBSpace else { continue }

        if !lefty || restore || !pointer {
            if typeID == CGImage.typeID {
                images.append(object)
            } else if let cg = bitmapRep.cgImage {
                images.append(cg)
            }
        } else {
            guard let flipped = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: bitmapRep.pixelsWide,
                pixelsHigh: bitmapRep.pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .calibratedRGB,
                bytesPerRow: 4 * bitmapRep.pixelsWide,
                bitsPerPixel: 32),
                  let ctx = NSGraphicsContext(bitmapImageRep: flipped) else { continue }

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ctx
            let transform = NSAffineTransform()
            transform.translateX(by: CGFloat(bitmapRep.pixelsWide), yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
            bitmapRep.draw(
                in: NSRect(x: 0, y: 0, width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: false,
                hints: nil)
            NSGraphicsContext.restoreGraphicsState()

            if let cg = flipped.cgImage { images.append(cg) }
        }
    }

    return applyCursorForIdentifier(
        frameCount: frameCountNum.intValue,
        frameDuration: CGFloat(frameDurationNum.doubleValue),
        hotSpot: hotSpot,
        size: size,
        images: images,
        ident: identifier,
        repeatCount: 0)
}

// MARK: - Apply full cape dictionary

@discardableResult
func applyCape(_ dictionary: [String: Any]) -> Bool {
    autoreleasepool {
        guard let cursors = dictionary[MCCursorDictionaryCursorsKey] as? [String: Any] else {
            return false
        }
        let name    = dictionary[MCCursorDictionaryCapeNameKey] as? String ?? ""
        let version = (dictionary[MCCursorDictionaryCapeVersionKey] as? NSNumber)?.floatValue ?? 0

        resetAllCursors()
        backupAllCursors()

        MMLog("Applying cape: \(name) \(String(format: "%.02f", version))")

        for (key, cape) in cursors {
            guard let capeDict = cape as? [String: Any] else { continue }
            MMLog("Hooking for \(key)")
            guard applyCapeForIdentifier(capeDict, identifier: key, restore: false) else {
                MMLog("\u{001B}[1m\u{001B}[31mFailed to hook identifier \(key) for some unknown reason. Bailing out...\u{001B}[0m")
                return false
            }
        }

        MCSetDefault(dictionary[MCCursorDictionaryIdentifierKey], key: MCPreferencesAppliedCursorKey)
        MMLog("\u{001B}[1m\u{001B}[32mApplied \(name) successfully!\u{001B}[0m")
        return true
    }
}

// MARK: - Apply cape at path

@discardableResult
func applyCapeAtPath(_ path: String) -> Bool {
    guard let cape = NSDictionary(contentsOfFile: path) as? [String: Any] else {
        MMLog("\u{001B}[1m\u{001B}[31mCould not find valid file at \(path) to apply\u{001B}[0m")
        return false
    }
    return applyCape(cape)
}
