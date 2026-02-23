// MCLibraryController.swift
// Mousecape
//
// Swift replacement for MCLibraryController.h / .m

import AppKit

@objc(MCLibraryController) class MCLibraryController: NSObject {

    @objc dynamic private(set) weak var appliedCape: MCCursorLibrary?
    @objc private(set) var undoManager: UndoManager = UndoManager()
    @objc private(set) var libraryURL: URL

    @objc dynamic private var _capes: NSMutableSet = NSMutableSet()

    // MARK: - Init

    @objc init(url: URL) {
        libraryURL = url
        super.init()
        undoManager = UndoManager()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willSaveNotification(_:)),
            name: NSNotification.Name(MCLibraryWillSaveNotificationName),
            object: nil)
        loadLibrary()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - URL for cape

    @objc func url(forCape cape: MCCursorLibrary) -> URL {
        return libraryURL
            .appendingPathComponent(cape.identifier)
            .appendingPathExtension("cape")
    }

    // MARK: - Load

    private func loadLibrary() {
        undoManager.disableUndoRegistration()
        _capes = NSMutableSet()

        let capesPath = libraryURL.path
        let contents  = (try? FileManager.default.contentsOfDirectory(atPath: capesPath)) ?? []
        let applied   = UserDefaults.standard.string(forKey: MCPreferencesAppliedCursorKey)

        for filename in contents {
            guard !filename.hasPrefix(".") else { continue }
            let fileURL = libraryURL.appendingPathComponent(filename)
            guard let library = MCCursorLibrary(contentsOfURL: fileURL) else { continue }
            if library.identifier == applied { appliedCape = library }
            addCape(library)
        }

        undoManager.enableUndoRegistration()
    }

    // MARK: - Import

    @objc func importCape(atURL url: URL) {
        if let lib = MCCursorLibrary(contentsOfURL: url) {
            importCape(lib)
        }
    }

    @objc func importCape(_ lib: MCCursorLibrary) {
        let existingIdentifiers = (_capes.value(forKeyPath: "identifier") as? Set<String>) ?? []
        if existingIdentifiers.contains(lib.identifier) {
            lib.identifier = lib.identifier + ".\(Foundation.UUID().uuidString)"
        }
        lib.fileURL = url(forCape: lib)
        lib.write(toFile: lib.fileURL!.path, atomically: false)
        addCape(lib)
    }

    // MARK: - Add / Remove

    @objc func addCape(_ cape: MCCursorLibrary) {
        let existingIdentifiers = (_capes.value(forKeyPath: "identifier") as? Set<String>) ?? []
        guard !_capes.contains(cape),
              !existingIdentifiers.contains(cape.identifier) else {
            NSLog("Not adding %@ to the library because an object with that identifier already exists",
                  cape.identifier)
            return
        }

        let change = NSSet(object: cape)
        willChangeValue(forKey: "capes", withSetMutation: .union, using: change as Set<AnyHashable>)
        cape.library = self
        _capes.add(cape)

        (undoManager.prepare(withInvocationTarget: self) as AnyObject).removeCape(cape)
        if !undoManager.isUndoing {
            undoManager.setActionName("Add \(cape.name)")
        }

        didChangeValue(forKey: "capes", withSetMutation: .union, using: change as Set<AnyHashable>)
        cape.undoManager.removeAllActions()
    }

    @objc func removeCape(_ cape: MCCursorLibrary) {
        let change = NSSet(object: cape)
        willChangeValue(forKey: "capes", withSetMutation: .minus, using: change as Set<AnyHashable>)

        if cape === appliedCape { restoreCape() }
        if cape.library === self { cape.library = nil }
        _capes.remove(cape)

        let trashPath = ("~/.Trash" as NSString).expandingTildeInPath
        let destURL = URL(fileURLWithPath: trashPath)
            .appendingPathComponent(cape.fileURL?.lastPathComponent ?? "\(cape.identifier).cape")

        let manager = FileManager.default
        try? manager.removeItem(at: destURL)
        if let src = cape.fileURL { try? manager.moveItem(at: src, to: destURL) }

        (undoManager.prepare(withInvocationTarget: self) as AnyObject).importCape(atURL: destURL)
        if !undoManager.isUndoing {
            undoManager.setActionName("Remove \(cape.name)")
        }

        didChangeValue(forKey: "capes", withSetMutation: .minus, using: change as Set<AnyHashable>)
    }

    // MARK: - Apply / Restore

    @objc func applyCape(_ cape: MCCursorLibrary) {
        guard let path = cape.fileURL?.path, applyCapeAtPath(path) else { return }
        appliedCape = cape
    }

    @objc func restoreCape() {
        resetAllCursors()
        appliedCape = nil
    }

    // MARK: - Query

    @objc func capes(withIdentifier identifier: String) -> NSSet {
        let pred = NSPredicate(format: "identifier == %@", identifier)
        return _capes.filtered(using: pred) as NSSet
    }

    @objc func dumpCursors(withProgressBlock block: ((Int, Int) -> Bool)?) -> Bool {
        let ts   = Date().timeIntervalSince1970
        let name = NSLocalizedString("Mousecape Dump", comment: "Mousecape dump cursor file name")
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("\(name) (\(ts)).cape")

        guard dumpCursorsToFile(path, progress: block) else { return false }

        DispatchQueue.main.async { [weak self] in
            self?.importCape(atURL: URL(fileURLWithPath: path))
        }
        return true
    }

    // MARK: - Notifications

    @objc private func willSaveNotification(_ note: NSNotification) {
        guard let cape = note.object as? MCCursorLibrary else { return }
        let oldURL = cape.fileURL
        cape.fileURL = url(forCape: cape)
        if let old = oldURL, old != cape.fileURL {
            do { try FileManager.default.removeItem(at: old) }
            catch { NSLog("Error removing cape after rename: %@", error.localizedDescription) }
        }
    }
}

// MARK: - Capes KVO alias

extension MCLibraryController {
    @objc var capes: NSSet { return _capes }
}
