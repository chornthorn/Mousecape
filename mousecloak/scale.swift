// scale.swift
// Mousecape
//
// Swift replacement for scale.h / scale.m

import Foundation

func cursorScale() -> Float {
    var value: Float = 1.0
    CGSGetCursorScale(CGSMainConnectionID(), &value)
    return value
}

func defaultCursorScale() -> Float {
    var scale = (MCDefault(MCPreferencesCursorScaleKey) as? NSNumber)?.floatValue ?? 1.0
    if scale < 0.5 || scale > 16 { scale = 1.0 }
    return scale
}

@discardableResult
func setCursorScale(_ scale: Float) -> Bool {
    if scale > 32 {
        MMLog("Not a good idea...")
        return false
    }
    if CGSSetCursorScale(CGSMainConnectionID(), scale) == noErr {
        MMLog("Successfully set cursor scale!")
        return true
    }
    MMLog("Somehow failed to set cursor scale!")
    return false
}
