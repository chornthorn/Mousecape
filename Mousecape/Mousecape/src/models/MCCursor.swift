// MCCursor.swift
// Mousecape
//
// Swift replacement for MCCursor.h / MCCursor.m

import AppKit

// MARK: - MCCursorScale

@objc enum MCCursorScale: UInt {
    case none   = 0
    case scale100  = 100
    case scale200  = 200
    case scale500  = 500
    case scale1000 = 1000
}

func cursorScaleForScale(_ scale: CGFloat) -> MCCursorScale {
    if scale < 0.0 { return .none }
    let raw = UInt(scale * 100)
    return MCCursorScale(rawValue: raw) ?? .none
}

// MARK: - MCCursor

@objc(MCCursor) class MCCursor: NSObject, NSCopying {

    // MARK: Public properties

    @objc dynamic var identifier: String {
        didSet { }
    }

    @objc var name: String {
        return nameForCursorIdentifier(identifier)
    }

    @objc dynamic var frameDuration: CGFloat = 1.0
    @objc dynamic var frameCount: Int = 1
    @objc dynamic var size: NSSize = .zero
    @objc dynamic var hotSpot: NSPoint = .zero

    // MARK: Private backing store

    /// Keyed by scale raw value string, e.g. "100", "200".
    @objc dynamic private(set) var representations: NSMutableDictionary = NSMutableDictionary()

    // MARK: Init

    override init() {
        identifier = Foundation.UUID().uuidString.replacingOccurrences(of: "-", with: "")
        super.init()
    }

    @objc convenience init?(cursorDictionary dict: [String: Any], ofVersion version: CGFloat) {
        self.init()
        guard readFromDictionary(dict, version: version) else { return nil }
    }

    @objc class func cursor(withDictionary dict: [String: Any], ofVersion version: CGFloat) -> MCCursor? {
        return MCCursor(cursorDictionary: dict, ofVersion: version)
    }

    // MARK: NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        let cursor = MCCursor()
        cursor.frameCount    = frameCount
        cursor.frameDuration = frameDuration
        cursor.size          = size
        cursor.representations = representations.mutableCopy() as! NSMutableDictionary
        cursor.hotSpot       = hotSpot
        cursor.identifier    = identifier
        return cursor
    }

    // MARK: KVO dependencies

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        var keyPaths = super.keyPathsForValuesAffectingValue(forKey: key)
        if key == "imageWithAllReps" {
            keyPaths.insert("representations")
        } else if key == "name" {
            keyPaths.insert("identifier")
        } else if key.hasPrefix("cursorImage") {
            let suffix = key.dropFirst("cursorImage".count)
            keyPaths.insert("cursorRep\(suffix)")
        }
        return keyPaths
    }

    // MARK: KVC for cursorRep*/cursorImage* keys

    override func value(forUndefinedKey key: String) -> Any? {
        if key.hasPrefix("cursorRep") || key.hasPrefix("cursorImage") {
            let isImage = key.hasPrefix("cursorImage")
            let prefix  = isImage ? "cursorImage" : "cursorRep"
            let scaleString = String(key.dropFirst(prefix.count))
            let scaleValue  = CGFloat(Double(scaleString) ?? 0) / 100.0
                guard let rep = representationForScale(cursorScaleForScale(scaleValue)) else { return nil }
                let image = NSImage(size: NSSize(width: Double(rep.pixelsWide) / Double(scaleValue),
                                                 height: Double(rep.pixelsHigh) / Double(scaleValue)))
                image.addRepresentation(rep)
                return image
            } else {
                return representationForScale(cursorScaleForScale(scaleValue))
            }
        }
        return super.value(forUndefinedKey: key)
    }

    override func setValue(_ value: Any?, forUndefinedKey key: String) {
        if key.hasPrefix("cursorRep") || key.hasPrefix("cursorImage") {
            let isImage = key.hasPrefix("cursorImage")
            let prefix  = isImage ? "cursorImage" : "cursorRep"
            let scaleString = String(key.dropFirst(prefix.count))
            let scaleValue  = CGFloat(Double(scaleString) ?? 0) / 100.0

            var rep = value as? NSImageRep
            if isImage, let image = value as? NSImage {
                rep = image.representations.first
            }
            setRepresentation(rep, forScale: cursorScaleForScale(scaleValue))
            return
        }
        super.setValue(value, forUndefinedKey: key)
    }

    // MARK: Representation management

    @objc func setRepresentation(_ imageRep: NSImageRep?, forScale scale: MCCursorScale) {
        let repKey = "\(scale.rawValue)"
        let kvoKey = "cursorRep\(scale.rawValue)"

        willChangeValue(forKey: "representations")
        willChangeValue(forKey: kvoKey)

        if let rep = imageRep as? NSBitmapImageRep {
            representations[repKey] = rep

            if representations.count == 1 {
                let s = CGFloat(scale.rawValue) / 100.0
                let w = s > 0 ? Double(rep.pixelsWide) / Double(s) : 0
                let h = s > 0 ? Double(rep.pixelsHigh) / Double(frameCount) / Double(s) : 0
                let newSize = NSSize(width: w, height: h)
                if newSize != .zero {
                    self.size = newSize
                }
            }
        } else if imageRep == nil {
            representations.removeObject(forKey: repKey)
        } else {
            representations[repKey] = imageRep
        }

        didChangeValue(forKey: kvoKey)
        didChangeValue(forKey: "representations")
    }

    @objc func removeRepresentation(forScale scale: MCCursorScale) {
        setRepresentation(nil, forScale: scale)
    }

    @objc func addFrame(_ frame: NSImageRep, forScale scale: MCCursorScale) {
        let existing = representationForScale(scale)
        let frames: [NSImageRep] = existing.map { [$0, frame] } ?? [frame]
        guard let newRep = MCCursor.composeRepresentation(withFrames: frames) else { return }

        let totalFrames = size.height > 0
            ? Int(Double(newRep.pixelsHigh) / Double(size.height))
            : 1
        if frameCount < totalFrames { frameCount = totalFrames }
        setRepresentation(newRep, forScale: scale)
    }

    @objc func representationForScale(_ scale: MCCursorScale) -> NSBitmapImageRep? {
        return representations["\(scale.rawValue)"] as? NSBitmapImageRep
    }

    @objc func representation(withScale scale: CGFloat) -> NSImageRep? {
        return representationForScale(cursorScaleForScale(scale))
    }

    // MARK: Compose helper

    @objc class func composeRepresentation(withFrames frames: [NSImageRep]) -> NSBitmapImageRep? {
        guard !frames.isEmpty else { return nil }
        guard frames.count > 1 else { return frames.first as? NSBitmapImageRep }

        let totalHeight = frames.map { $0.pixelsHigh }.reduce(0, +)
        let width = frames[0].pixelsWide

        guard let newRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: totalHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 4 * width,
            bitsPerPixel: 32) else { return nil }

        guard let ctx = NSGraphicsContext(bitmapImageRep: newRep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        var currentY = 0
        for idx in stride(from: frames.count - 1, through: 0, by: -1) {
            let rep = frames[idx]
            guard rep.pixelsWide == width else {
                NSLog("Can't create representation from images of different widths")
                NSGraphicsContext.restoreGraphicsState()
                return nil
            }
            rep.draw(in: NSRect(x: 0, y: currentY, width: rep.pixelsWide, height: rep.pixelsHigh),
                     from: .zero,
                     operation: .sourceOver,
                     fraction: 1.0,
                     respectFlipped: true,
                     hints: nil)
            currentY += rep.pixelsHigh
        }

        NSGraphicsContext.restoreGraphicsState()
        return newRep
    }

    // MARK: Dictionary representation

    @objc func dictionaryRepresentation() -> [String: Any] {
        var drep: [String: Any] = [
            MCCursorDictionaryFrameCountKey:    frameCount,
            MCCursorDictionaryFrameDuratiomKey: frameDuration,
            MCCursorDictionaryHotSpotXKey:      hotSpot.x,
            MCCursorDictionaryHotSpotYKey:      hotSpot.y,
            MCCursorDictionaryPointsWideKey:    size.width,
            MCCursorDictionaryPointsHighKey:    size.height,
        ]

        var pngs: [Data] = []
        for key in representations.allKeys {
            if let rep = representations[key] as? NSBitmapImageRep,
               let data = rep.ensuredSRGBSpace.tiffRepresentation(using: .lzw, factor: 1.0) {
                pngs.append(data)
            }
        }
        drep[MCCursorDictionaryRepresentationsKey] = pngs
        return drep
    }

    // MARK: Derived image

    @objc func imageWithAllReps() -> NSImage {
        let image = NSImage(size: NSSize(width: size.width, height: size.height * CGFloat(frameCount)))
        image.addRepresentations(representations.allValues as! [NSImageRep])
        return image
    }

    // MARK: Private reading

    private func readFromDictionary(_ dict: [String: Any], version: CGFloat) -> Bool {
        guard !dict.isEmpty else { return false }

        guard let frameCountNum    = dict[MCCursorDictionaryFrameCountKey] as? NSNumber,
              let frameDurationNum = dict[MCCursorDictionaryFrameDuratiomKey] as? NSNumber,
              let hotSpotXNum      = dict[MCCursorDictionaryHotSpotXKey] as? NSNumber,
              let hotSpotYNum      = dict[MCCursorDictionaryHotSpotYKey] as? NSNumber,
              let pointsWideNum    = dict[MCCursorDictionaryPointsWideKey] as? NSNumber,
              let pointsHighNum    = dict[MCCursorDictionaryPointsHighKey] as? NSNumber else { return false }

        guard version >= 2.0 else { return false }

        frameCount    = frameCountNum.intValue
        frameDuration = CGFloat(frameDurationNum.doubleValue)
        hotSpot       = NSPoint(x: hotSpotXNum.doubleValue, y: hotSpotYNum.doubleValue)

        let pointsWide = pointsWideNum.doubleValue
        let pointsHigh = pointsHighNum.doubleValue

        if let reps = dict[MCCursorDictionaryRepresentationsKey] as? [Data] {
            for data in reps {
                guard let rep = NSBitmapImageRep(data: data) else { continue }
                rep.size = NSSize(width: size.width, height: size.height * CGFloat(frameCount))
                let scale = pointsWide > 0 ? CGFloat(rep.pixelsWide) / CGFloat(pointsWide) : 1
                setRepresentation(rep.retaggedSRGBSpace, forScale: cursorScaleForScale(scale))
            }
        }

        size = NSSize(width: pointsWide, height: pointsHigh)
        return true
    }

    // MARK: Equality

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MCCursor else { return false }
        return other.frameCount    == frameCount &&
               other.frameDuration == frameDuration &&
               NSEqualSizes(other.size, size) &&
               NSEqualPoints(other.hotSpot, hotSpot) &&
               other.identifier == identifier
    }
}
