// backup.swift
// Mousecape
//
// Swift replacement for backup.h / backup.m

import Foundation

func backupStringForIdentifier(_ identifier: String) -> String {
    return "com.alexzielenski.mousecape.\(identifier)"
}

func backupCursorForIdentifier(_ ident: String) {
    var registered = false
    MCIsCursorRegistered(CGSMainConnectionID(), ident, &registered)
    guard registered else { return }

    let backupIdent = backupStringForIdentifier(ident)
    var backupRegistered = false
    MCIsCursorRegistered(CGSMainConnectionID(), backupIdent, &backupRegistered)
    guard !backupRegistered else { return }

    if let cape = capeWithIdentifier(ident) {
        applyCapeForIdentifier(cape, identifier: backupIdent, restore: true)
    }
}

func backupAllCursors() {
    let backupKey = backupStringForIdentifier("com.apple.coregraphics.Arrow")
    var arrowRegistered = false
    MCIsCursorRegistered(CGSMainConnectionID(), backupKey, &arrowRegistered)

    if arrowRegistered {
        MMLog("Skipping backup, backup already exists")
        return
    }

    for key in defaultCursors {
        backupCursorForIdentifier(key)
    }
}
