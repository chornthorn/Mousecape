// MCFormatters.swift
// Mousecape
//
// Swift replacement for MCFormatters.h / MCFormatters.m

import Foundation
import AppKit

// MARK: - MCPointFormatter

@objc(MCPointFormatter) class MCPointFormatter: Formatter {

    override func string(for obj: Any?) -> String? {
        guard let val = obj as? NSValue else { return nil }
        return NSStringFromPoint(val.pointValue)
    }

    override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        obj?.pointee = NSValue(point: NSPointFromString(string))
        return true
    }

    override func isPartialStringValid(
        _ partialString: String,
        newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        let components = partialString.components(separatedBy: ",")
        if components.count <= 1 { return true }
        if components.count == 2 {
            newString?.pointee = NSStringFromPoint(NSPointFromString(partialString)) as NSString
            return true
        }
        error?.pointee = NSError(
            domain: MCErrorDomain,
            code: MCErrorCode.invalidFormat.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Invalid format", comment: ""),
                NSLocalizedFailureReasonErrorKey: NSLocalizedString(
                    "Must follow format of: \"{0.0, 0.0}\".", comment: ""),
            ]).localizedDescription as NSString
        return false
    }
}

// MARK: - MCSizeFormatter

@objc(MCSizeFormatter) class MCSizeFormatter: Formatter {

    override func string(for obj: Any?) -> String? {
        guard let val = obj as? NSValue else { return nil }
        return NSStringFromSize(val.sizeValue)
    }

    override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        obj?.pointee = NSValue(size: NSSizeFromString(string))
        return true
    }

    override func isPartialStringValid(
        _ partialString: String,
        newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        let components = partialString.components(separatedBy: ",")
        if components.count <= 1 { return true }
        if components.count == 2 {
            newString?.pointee = NSStringFromSize(NSSizeFromString(partialString)) as NSString
            return true
        }
        error?.pointee = NSError(
            domain: MCErrorDomain,
            code: MCErrorCode.invalidFormat.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Invalid format", comment: ""),
                NSLocalizedFailureReasonErrorKey: NSLocalizedString(
                    "Must follow format of: \"{0.0, 0.0}\".", comment: ""),
            ]).localizedDescription as NSString
        return false
    }
}
