// LibraryStore.swift
// Mousecape
//
// ObservableObject bridge between MCLibraryController (KVO) and SwiftUI.

import SwiftUI
import AppKit

final class LibraryStore: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var capes: [MCCursorLibrary] = []
    @Published var appliedCape: MCCursorLibrary?

    /// Cape currently open in the editor window.
    @Published var editingCape: MCCursorLibrary?

    /// Show/hide the dump-progress sheet.
    @Published var isDumping: Bool = false
    @Published var dumpProgress: (current: Int, total: Int) = (0, 0)

    // MARK: - Underlying controller

    let controller: MCLibraryController

    // MARK: - Init

    override init() {
        let capesPath = Self.capesPath()
        self.controller = MCLibraryController(url: URL(fileURLWithPath: capesPath))
        super.init()

        // KVO – capes set changes
        controller.addObserver(self, forKeyPath: "capes",
                               options: [.initial, .new, .old],
                               context: nil)
        // KVO – applied cape changes
        controller.addObserver(self, forKeyPath: "appliedCape",
                               options: [.initial, .new],
                               context: nil)
    }

    deinit {
        controller.removeObserver(self, forKeyPath: "capes")
        controller.removeObserver(self, forKeyPath: "appliedCape")
    }

    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if keyPath == "capes" {
                self.refreshCapes()
            } else if keyPath == "appliedCape" {
                self.appliedCape = self.controller.appliedCape
            }
        }
    }

    // MARK: - Helpers

    private func refreshCapes() {
        let sorted = controller.capes.sortedArray(using: [
            NSSortDescriptor(key: "name", ascending: true,
                             selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
            NSSortDescriptor(key: "author", ascending: true,
                             selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
        ])
        capes = sorted.compactMap { $0 as? MCCursorLibrary }
        appliedCape = controller.appliedCape
    }

    private static func capesPath() -> String {
        var error: NSError?
        return FileManager.default.findOrCreateDirectory(
            .applicationSupportDirectory,
            inDomain: .userDomainMask,
            appendPathComponent: "Mousecape/capes",
            error: &error) ?? ""
    }

    // MARK: - Actions

    func importCape(at url: URL) {
        controller.importCape(atURL: url)
    }

    func importCape(_ library: MCCursorLibrary) {
        controller.importCape(library)
    }

    func removeCape(_ cape: MCCursorLibrary) {
        if editingCape === cape { editingCape = nil }
        controller.removeCape(cape)
    }

    func applyCape(_ cape: MCCursorLibrary) {
        controller.applyCape(cape)
        UserDefaults.standard.set(cape.identifier, forKey: MCPreferencesAppliedCursorKey)
    }

    func restoreCape() {
        controller.restoreCape()
        UserDefaults.standard.removeObject(forKey: MCPreferencesAppliedCursorKey)
    }

    func dumpCursors() {
        isDumping = true
        dumpProgress = (0, 0)
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.controller.dumpCursors(withProgressBlock: { current, total in
                DispatchQueue.main.async {
                    self?.dumpProgress = (current, total)
                }
                return true
            })
            DispatchQueue.main.async {
                self?.isDumping = false
                self?.dumpProgress = (0, 0)
            }
        }
    }

    func createMightyMouseCape(at url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        let metadata: [String: Any] = [
            "name":       name,
            "version":    1.0,
            "author":     NSLocalizedString("Unknown", comment: "MightyMouse Import Default Author"),
            "identifier": "local.import.\(name).\(Int(Date().timeIntervalSinceReferenceDate))",
        ]
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let cape = createCapeFromMightyMouse(dict, metadata: metadata),
              let library = MCCursorLibrary(dictionary: cape) else { return }
        importCape(library)
    }
}
