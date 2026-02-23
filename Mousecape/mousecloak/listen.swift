// listen.swift
// Mousecape
//
// Swift replacement for listen.h / listen.m

import Foundation
import SystemConfiguration
import AppKit

func appliedCapePathForUser(_ user: String) -> String {
    let home       = NSHomeDirectoryForUser(user) ?? NSHomeDirectory()
    let ident      = MCDefaultFor(MCPreferencesAppliedCursorKey,
                                  user: user,
                                  host: kCFPreferencesCurrentHost as String) as? String ?? ""
    let appSupport = (home as NSString).appendingPathComponent("Library/Application Support")
    return ((((appSupport as NSString)
        .appendingPathComponent("Mousecape/capes") as NSString)
        .appendingPathComponent(ident) as NSString)
        .appendingPathExtension("cape") ?? ident)
}

private func userSpaceChanged(
    _ store: SCDynamicStore,
    _ changedKeys: CFArray,
    _ info: UnsafeMutableRawPointer?
) {
    guard let user = SCDynamicStoreCopyConsoleUser(store, nil, nil) else { return }
    let userName = user as String
    MMLog("Current user is \(userName)")
    guard userName != "loginwindow" else { return }

    let appliedPath = appliedCapePathForUser(userName)
    MMLog("\u{001B}[1m\u{001B}[32mUser Space Changed to \(userName), applying cape...\u{001B}[0m")
    if !applyCapeAtPath(appliedPath) {
        MMLog("\u{001B}[1m\u{001B}[31mApplication of cape failed\u{001B}[0m")
    }
    setCursorScale(defaultCursorScale())
}

private func reconfigurationCallback(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ userInfo: UnsafeMutableRawPointer?
) {
    MMLog("Reconfigure user space")
    applyCapeAtPath(appliedCapePathForUser(NSUserName()))
    var scale: Float = 1.0
    CGSGetCursorScale(CGSMainConnectionID(), &scale)
    CGSSetCursorScale(CGSMainConnectionID(), scale + 0.3)
    CGSSetCursorScale(CGSMainConnectionID(), scale)
}

func listener() {
    let store = SCDynamicStoreCreate(nil, "com.apple.dts.ConsoleUser" as CFString,
                                     userSpaceChanged, nil)!

    let key  = SCDynamicStoreKeyCreateConsoleUser(nil)!
    let keys = [key] as CFArray
    let success = SCDynamicStoreSetNotificationKeys(store, keys, nil)
    assert(success)

    NSApplicationLoad()
    CGDisplayRegisterReconfigurationCallback(reconfigurationCallback, nil)
    MMLog("\u{001B}[1m\u{001B}[36mListening for Display changes\u{001B}[0m")

    guard let rls = SCDynamicStoreCreateRunLoopSource(nil, store, 0) else {
        fatalError("Could not create run loop source")
    }
    MMLog("\u{001B}[1m\u{001B}[36mListening for User changes\u{001B}[0m")

    applyCapeAtPath(appliedCapePathForUser(NSUserName()))
    setCursorScale(defaultCursorScale())

    CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .defaultMode)
    CFRunLoopRun()

    // Cleanup
    CFRunLoopSourceInvalidate(rls)
}
