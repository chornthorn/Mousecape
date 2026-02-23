// restore.swift
// Mousecape
//
// Swift replacement for restore.h / restore.m

import Foundation

func restoreStringForIdentifier(_ identifier: String) -> String {
    let prefix = "com.alexzielenski.mousecape."
    return String(identifier.dropFirst(prefix.count))
}

func restoreCursorForIdentifier(_ ident: String) {
    var registered = false
    MCIsCursorRegistered(CGSMainConnectionID(), ident, &registered)

    let restoreIdent = restoreStringForIdentifier(ident)
    let cape = capeWithIdentifier(ident)

    MMLog("Restoring cursor \(restoreIdent) from \(ident)")
    if let cape = cape, registered {
        applyCapeForIdentifier(cape, identifier: restoreIdent, restore: true)
    }

    ident.withCString { cStr in
        CGSRemoveRegisteredCursor(CGSMainConnectionID(), UnsafeMutablePointer(mutating: cStr), false)
    }
}

func resetAllCursors() {
    MMLog("Restoring cursors...")

    for key in defaultCursors {
        restoreCursorForIdentifier(backupStringForIdentifier(key))
    }

    MMLog("Restoring core cursors...")
    if CoreCursorUnregisterAll(CGSMainConnectionID()) == 0 {
        MCSetDefault(nil, key: MCPreferencesAppliedCursorKey)

        for x in 0..<45 {
            CoreCursorSet(CGSMainConnectionID(), Int32(x))
        }

        MMLog("\u{001B}[1m\u{001B}[32mSuccessfully restored all cursors.\u{001B}[0m")
    } else {
        MMLog("\u{001B}[1m\u{001B}[31mReceived an error while restoring core cursors.\u{001B}[0m")
    }
}
