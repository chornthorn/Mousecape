// MCAppDelegate.swift
// Mousecape
//
// Legacy app delegate — superseded by MousecapeApp.swift (SwiftUI @main).
// Kept for reference but not used as the application entry point.

import AppKit
import ServiceManagement

// MCAppDelegate is kept as a reference but is no longer the app entry point.
// The SwiftUI @main entry point is MousecapeApp.swift.
@objc(MCAppDelegate) class MCAppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var toggleHelperItem: NSMenuItem?

    // MARK: - NSApplicationDelegate

    func applicationWillFinishLaunching(_ notification: Notification) { }

    func applicationDidFinishLaunching(_ notification: Notification) { }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

