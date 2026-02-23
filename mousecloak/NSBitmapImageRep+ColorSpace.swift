// NSBitmapImageRep+ColorSpace.swift
// Mousecape
//
// Swift replacement for NSBitmapImageRep+ColorSpace.h / .m

import AppKit

extension NSBitmapImageRep {
    /// Returns a copy of this rep converted to sRGB (or gray gamma 2.2 for grayscale images).
    var ensuredSRGBSpace: NSBitmapImageRep {
        let targetSpace: NSColorSpace = colorSpace.numberOfColorComponents == 1
            ? .genericGamma22Gray
            : .sRGB
        return bitmapImageRepByConverting(to: targetSpace, renderingIntent: .default) ?? self
    }

    /// Returns a copy of this rep retagged with sRGB (or gray gamma 2.2 for grayscale images).
    var retaggedSRGBSpace: NSBitmapImageRep {
        let targetSpace: NSColorSpace = colorSpace.numberOfColorComponents == 1
            ? .genericGamma22Gray
            : .sRGB
        return bitmapImageRepByRetagging(with: targetSpace) ?? self
    }
}
