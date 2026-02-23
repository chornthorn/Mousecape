// MCPrefs.swift
// Mousecape
//
// Swift replacement for MCPrefs.h / MCPrefs.m

import Foundation

let kMCDomain = "com.alexzielenski.Mousecape"

let MCPreferencesAppliedCursorKey          = "MCAppliedCursor"
let MCPreferencesAppliedClickActionKey     = "MCLibraryClickAction"
let MCPreferencesCursorScaleKey            = "MCCursorScale"
let MCPreferencesDoubleActionKey           = "MCDoubleAction"
let MCPreferencesHandednessKey             = "MCHandedness"
let MCSuppressDeleteLibraryConfirmationKey = "MCSuppressDeleteLibraryConfirmationKey"
let MCSuppressDeleteCursorConfirmationKey  = "MCSuppressDeleteCursorConfirmationKey"

func MCDefaultFor(_ key: String, user: String, host: String) -> Any? {
    return CFPreferencesCopyValue(
        key as CFString,
        kMCDomain as CFString,
        user as CFString,
        host as CFString)
}

func MCDefault(_ key: String) -> Any? {
    return CFPreferencesCopyAppValue(key as CFString, kMCDomain as CFString)
}

func MCFlag(_ key: String) -> Bool {
    return (MCDefault(key) as? NSNumber)?.boolValue ?? false
}

func MCSetDefaultFor(_ value: Any?, key: String, user: String, host: String) {
    CFPreferencesSetValue(
        key as CFString,
        value as CFPropertyList?,
        kMCDomain as CFString,
        user as CFString,
        host as CFString)
}

func MCSetDefault(_ value: Any?, key: String) {
    MCSetDefaultFor(
        value,
        key: key,
        user: kCFPreferencesCurrentUser as String,
        host: kCFPreferencesCurrentHost as String)
}

func MCSetFlag(_ value: Bool, key: String) {
    MCSetDefault(NSNumber(value: value), key: key)
}
