// MCAppDelegate.swift
// Mousecape
//
// Swift replacement for MCAppDelegate.h / .m

import AppKit
import ServiceManagement

@NSApplicationMain
@objc(MCAppDelegate) class MCAppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var toggleHelperItem: NSMenuItem?
    @objc var libraryWindowController: MCLibraryWindowController?

    private var _preferencesWindowController: MASPreferencesWindowController?

    private var preferencesWindowController: MASPreferencesWindowController {
        if _preferencesWindowController == nil {
            let general = MCGeneralPreferencesController()
            _preferencesWindowController = MASPreferencesWindowController(
                viewControllers: [general],
                title: NSLocalizedString("Preferences", comment: "Preferences Window Title"))
        }
        return _preferencesWindowController!
    }

    // MARK: - NSApplicationDelegate

    func applicationWillFinishLaunching(_ notification: Notification) {
        libraryWindowController = MCLibraryWindowController(windowNibName: "Library")
        libraryWindowController?.loadWindow()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureHelperToolMenuItem()
        libraryWindowController?.showWindow(self)

        if let applied = libraryWindowController?.libraryViewController?.libraryController?.appliedCape {
            libraryWindowController?.libraryViewController?.libraryController?.applyCape(applied)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        guard filename.pathExtension.lowercased() == "cape" else { return false }
        let url = URL(fileURLWithPath: filename)
        libraryWindowController?.libraryViewController?.libraryController?.importCape(atURL: url)
        return true
    }

    // MARK: - Helper Tool

    private func configureHelperToolMenuItem() {
        let dict = SMJobCopyDictionary(kSMDomainUserLaunchd,
                                       "com.alexzielenski.mousecloakhelper" as CFString)
        let installed = dict != nil
        toggleHelperItem?.tag   = installed ? 1 : 0
        toggleHelperItem?.title = installed
            ? NSLocalizedString("Uninstall Helper Tool", comment: "Uninstall Helper Tool Menu Item")
            : NSLocalizedString("Install Helper Tool",   comment: "Install Helper Tool Menu Item")
        if let d = dict { CFRelease(d) }
    }

    @IBAction func toggleInstall(_ sender: NSMenuItem) {
        guard let item = toggleHelperItem else { return }
        let shouldInstall = item.tag == 0
        let success = SMLoginItemSetEnabled(
            "com.alexzielenski.mousecloakhelper" as CFString, shouldInstall)

        if success && shouldInstall {
            item.tag   = 1
            item.title = NSLocalizedString("Uninstall Helper Tool", comment: "")
            showAlert(
                title:   NSLocalizedString("Success", comment: "Helper Tool Install Result Title Success"),
                message: NSLocalizedString("The Mousecape helper was successfully installed",
                                           comment: "Helper Tool Install Success Result"),
                button1: NSLocalizedString("Sweet",  comment: "Helper Tool Install Result Gratitude 1"),
                button2: NSLocalizedString("Thanks", comment: "Helper Tool Install Result Gratitude 2"))
        } else if success {
            item.tag   = 0
            item.title = NSLocalizedString("Install Helper Tool", comment: "")
            showAlert(
                title:   NSLocalizedString("Success", comment: "Helper Tool Uninstall Result Title Success"),
                message: NSLocalizedString("The Mousecape helper was successfully uninstalled",
                                           comment: "Helper Tool Uninstall Success Result"),
                button1: NSLocalizedString("Sweet",  comment: "Helper Tool Uninstall Result Gratitude 1"),
                button2: NSLocalizedString("Thanks", comment: "Helper Tool Uninstall Result Gratitude 2"))
        } else {
            showAlert(
                title:   NSLocalizedString("Failure", comment: "Helper Tool Result Title Failure"),
                message: NSLocalizedString("The action did not complete successfully",
                                           comment: "Helper Tool Result Useless Failure Description"),
                button1: NSLocalizedString("OK", comment: "Helper Tool Result Failure OK"))
        }
    }

    private func showAlert(title: String, message: String, button1: String, button2: String? = nil) {
        let alert = NSAlert()
        alert.messageText     = title
        alert.informativeText = message
        alert.addButton(withTitle: button1)
        if let b2 = button2 { alert.addButton(withTitle: b2) }
        alert.runModal()
    }

    // MARK: - Interface Actions

    @IBAction func restoreCape(_ sender: Any) {
        libraryWindowController?.libraryViewController?.libraryController?.restoreCape()
    }

    @IBAction func convertCape(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["MightyMouse"]
        panel.title   = NSLocalizedString("Import", comment: "MightyMouse Import Panel Title")
        panel.message = NSLocalizedString("Choose a MightyMouse file to import",
                                          comment: "MightyMouse Import Panel description")
        panel.prompt  = NSLocalizedString("Import", comment: "MightyMouse Import Panel Prompt")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = url.deletingPathExtension().lastPathComponent
        let metadata: [String: Any] = [
            "name":       name,
            "version":    1.0,
            "author":     NSLocalizedString("Unknown", comment: "MightyMouse Import Default Author"),
            "identifier": "local.import.\(name).\(Date.timeIntervalSinceReferenceDate)",
        ]
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let cape = createCapeFromMightyMouse(dict, metadata: metadata),
              let library = MCCursorLibrary(dictionary: cape) else { return }
        libraryWindowController?.libraryViewController?.libraryController?.importCape(library)
    }

    @IBAction func newDocument(_ sender: Any) {
        libraryWindowController?.libraryViewController?.libraryController?.importCape(MCCursorLibrary())
    }

    @IBAction func openDocument(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["cape"]
        panel.title   = NSLocalizedString("Import", comment: "Mousecape Import Title")
        panel.message = NSLocalizedString("Choose a Mousecape to import",
                                          comment: "Mousecape Import description")
        panel.prompt  = NSLocalizedString("Import", comment: "Mousecape Import Prompt")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        libraryWindowController?.libraryViewController?.libraryController?.importCape(atURL: url)
    }

    @IBAction func showPreferences(_ sender: Any) {
        preferencesWindowController.showWindow(sender)
    }
}
