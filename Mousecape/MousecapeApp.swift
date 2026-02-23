// MousecapeApp.swift
// Mousecape
//
// SwiftUI @main entry point — replaces MCAppDelegate.swift.

import SwiftUI
import AppKit
import ServiceManagement

@main
struct MousecapeApp: App {

    @StateObject private var store = LibraryStore()

    var body: some Scene {
        // MARK: - Library window
        WindowGroup("Mousecape", id: "library") {
            LibraryView()
                .environmentObject(store)
                .frame(minWidth: 502, minHeight: 310)
                .onAppear {
                    // Re-apply the previously active cape on launch.
                    if let applied = store.controller.appliedCape {
                        store.applyCape(applied)
                    }
                }
        }
        .commands {
            // File menu additions
            CommandGroup(replacing: .newItem) {
                Button(NSLocalizedString("New Cape", comment: "New Cape menu item")) {
                    store.importCape(MCCursorLibrary())
                }
                .keyboardShortcut("n")

                Button(NSLocalizedString("Import Cape…", comment: "Import Cape menu item")) {
                    openCapeImportPanel()
                }
                .keyboardShortcut("o")

                Button(NSLocalizedString("Import MightyMouse…",
                                        comment: "Import MightyMouse menu item")) {
                    openMightyMousePanel()
                }
                .keyboardShortcut("i")
            }

            CommandGroup(after: .saveItem) {
                Divider()
                Button(NSLocalizedString("Restore Default Cursors",
                                        comment: "Restore cursors menu item")) {
                    store.restoreCape()
                }
                Button(NSLocalizedString("Dump Cursors…",
                                        comment: "Dump cursors menu item")) {
                    store.dumpCursors()
                }
            }

            // Mousecape menu additions
            CommandGroup(after: .appInfo) {
                Button(helperInstalled
                       ? NSLocalizedString("Uninstall Helper Tool",
                                           comment: "Uninstall Helper Tool Menu Item")
                       : NSLocalizedString("Install Helper Tool",
                                           comment: "Install Helper Tool Menu Item")) {
                    toggleHelperTool()
                }
            }
        }

        // MARK: - Edit window
        Window(NSLocalizedString("Edit", comment: "Edit window title"), id: "edit") {
            EditView()
                .environmentObject(store)
                .frame(minWidth: 500, minHeight: 296)
        }

        // MARK: - Settings
        Settings {
            SettingsView()
        }
    }

    // MARK: - Helper tool

    private var helperInstalled: Bool {
        let result = SMJobCopyDictionary(kSMDomainUserLaunchd,
                                         "com.alexzielenski.mousecloakhelper" as CFString)
        if let unmanaged = result {
            _ = unmanaged.takeRetainedValue()   // Balance the Copy retain
            return true
        }
        return false
    }

    private func toggleHelperTool() {
        let shouldInstall = !helperInstalled
        let bundleID = "com.alexzielenski.mousecloakhelper" as CFString
        let success = SMLoginItemSetEnabled(bundleID, shouldInstall)
        let title   = success
            ? NSLocalizedString("Success", comment: "Helper Tool Result Title Success")
            : NSLocalizedString("Failure", comment: "Helper Tool Result Title Failure")
        let message = success
            ? (shouldInstall
               ? NSLocalizedString("The Mousecape helper was successfully installed",
                                   comment: "Helper install success")
               : NSLocalizedString("The Mousecape helper was successfully uninstalled",
                                   comment: "Helper uninstall success"))
            : NSLocalizedString("The action did not complete successfully",
                                comment: "Helper result failure")

        let alert = NSAlert()
        alert.messageText     = title
        alert.informativeText = message
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }

    // MARK: - Import helpers

    private func openCapeImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "cape")].compactMap { $0 }
        panel.title   = NSLocalizedString("Import", comment: "Mousecape Import Title")
        panel.message = NSLocalizedString("Choose a Mousecape to import",
                                          comment: "Mousecape Import description")
        panel.prompt  = NSLocalizedString("Import", comment: "Mousecape Import Prompt")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.importCape(at: url)
    }

    private func openMightyMousePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "MightyMouse")].compactMap { $0 }
        panel.title   = NSLocalizedString("Import", comment: "MightyMouse Import Panel Title")
        panel.message = NSLocalizedString("Choose a MightyMouse file to import",
                                          comment: "MightyMouse Import Panel description")
        panel.prompt  = NSLocalizedString("Import", comment: "MightyMouse Import Panel Prompt")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.createMightyMouseCape(at: url)
    }
}
