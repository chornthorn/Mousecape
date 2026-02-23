// MCCursorLibrary.swift
// Mousecape
//
// Swift replacement for MCCursorLibrary.h / MCCursorLibrary.m

import AppKit

let MCLibraryWillSaveNotificationName = "MCLibraryWillSave"
let MCLibraryDidSaveNotificationName  = "MCLibraryDidSave"

@objc(MCCursorLibrary) class MCCursorLibrary: NSObject, NSCopying {

    // MARK: - Public properties

    @objc dynamic var name: String       = NSLocalizedString("Unnamed", comment: "Default New Cape Name")
    @objc dynamic var author: String     = NSUserName()
    @objc dynamic var identifier: String = ""
    @objc dynamic var version: NSNumber  = 1.0
    @objc dynamic var fileURL: URL?
    @objc weak var library: MCLibraryController?

    @objc dynamic var isInCloud: Bool = false
    @objc dynamic var isHiDPI: Bool   = false

    @objc private(set) var undoManager: NSUndoManager = NSUndoManager()

    @objc dynamic private var changeCount: Int     = 0
    @objc dynamic private var lastChangeCount: Int = 0

    @objc var isDirty: Bool { return changeCount != lastChangeCount }

    // MARK: - Private backing store

    @objc dynamic private(set) var cursors: NSMutableSet = NSMutableSet()

    private var observers: [NSObjectProtocol] = []
    private var oldIdentifier: String?

    // MARK: - Factory methods

    @objc class func cursorLibrary(withContentsOfFile path: String) -> MCCursorLibrary? {
        return MCCursorLibrary(contentsOfFile: path)
    }

    @objc class func cursorLibrary(withContentsOfURL url: URL) -> MCCursorLibrary? {
        return MCCursorLibrary(contentsOfURL: url)
    }

    @objc class func cursorLibrary(withDictionary dictionary: [String: Any]) -> MCCursorLibrary? {
        return MCCursorLibrary(dictionary: dictionary)
    }

    @objc class func cursorLibrary(withCursors cursorSet: NSSet) -> MCCursorLibrary {
        return MCCursorLibrary(cursors: cursorSet)
    }

    // MARK: - Init

    override init() {
        super.init()
        commonInit()
    }

    @objc convenience init?(contentsOfFile path: String) {
        self.init(contentsOfURL: URL(fileURLWithPath: path))
    }

    @objc convenience init?(contentsOfURL url: URL) {
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        self.init(dictionary: dict)
        self.fileURL = url
    }

    @objc convenience init?(dictionary: [String: Any]) {
        self.init()
        guard readFromDictionary(dictionary) else { return nil }
    }

    @objc convenience init(cursors cursorSet: NSSet) {
        self.init()
        self.cursors = cursorSet.mutableCopy() as! NSMutableSet
    }

    private func commonInit() {
        undoManager = NSUndoManager()
        identifier  = "local.\(author).Unnamed.\(Date.timeIntervalSinceReferenceDate)"
        cursors     = NSMutableSet()

        let center = NotificationCenter.default
        weak var weakSelf = self

        let ob1 = center.addObserver(
            forName: NSUndoManager.didCloseUndoGroupNotification,
            object: undoManager, queue: nil) { _ in
            weakSelf?.updateChangeCount(.changeDone)
        }
        let ob2 = center.addObserver(
            forName: NSUndoManager.didUndoChangeNotification,
            object: undoManager, queue: nil) { _ in
            weakSelf?.updateChangeCount(.changeUndone)
        }
        let ob3 = center.addObserver(
            forName: NSUndoManager.didRedoChangeNotification,
            object: undoManager, queue: nil) { _ in
            weakSelf?.updateChangeCount(.changeRedone)
        }
        observers = [ob1, ob2, ob3]

        startObservingProperties()
    }

    deinit {
        stopObservingProperties()
        for cursor in cursors {
            if let c = cursor as? MCCursor { stopObservingCursor(c) }
        }
        for ob in observers {
            NotificationCenter.default.removeObserver(ob)
        }
    }

    // MARK: - NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        let lib = MCCursorLibrary(cursors: self.cursors)
        lib.undoManager.disableUndoRegistration()
        lib.name        = name
        lib.author      = author
        lib.isHiDPI     = isHiDPI
        lib.isInCloud   = isInCloud
        lib.version     = version
        lib.identifier  = identifier + ".\(Date.timeIntervalSinceReferenceDate)"
        lib.undoManager.enableUndoRegistration()
        return lib
    }

    // MARK: - KVO dependencies

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        var keyPaths = super.keyPathsForValuesAffectingValue(forKey: key)
        if key == "dirty" {
            keyPaths.formUnion(["changeCount", "lastChangeCount"])
        }
        return keyPaths
    }

    // MARK: - Undo property maps

    private class func undoProperties() -> [String: String] {
        return [
            "identifier": NSLocalizedString("identifier", comment: "Undo change cape identifier suffix"),
            "name":       NSLocalizedString("name", comment: "Undo change cape name suffix"),
            "author":     NSLocalizedString("author", comment: "Undo change cape author suffix"),
            "isHiDPI":    NSLocalizedString("hiDPI", comment: "Undo change cape hidpi suffix"),
            "version":    NSLocalizedString("version", comment: "Undo change cape version suffix"),
        ]
    }

    private class func cursorUndoProperties() -> [String: String] {
        return [
            "identifier"   : NSLocalizedString("cursor type", comment: "Undo change cursor type suffix"),
            "frameDuration": NSLocalizedString("frame duration", comment: "Undo change cursor frame duration suffix"),
            "frameCount"   : NSLocalizedString("frame count", comment: "Undo change cursor frame count suffix"),
            "size"         : NSLocalizedString("dimensions", comment: "Undo change cursor dimensions suffix"),
            "hotSpot"      : NSLocalizedString("hotspot", comment: "Undo change cursor hotspot suffix"),
            "cursorRep100" : NSLocalizedString("1x Representation", comment: "Undo change cursor 1x rep suffix"),
            "cursorRep200" : NSLocalizedString("2x Rep", comment: "Undo change cursor 2x rep suffix"),
            "cursorRep500" : NSLocalizedString("5x Rep", comment: "Undo change cursor 5x rep suffix"),
            "cursorRep1000": NSLocalizedString("10x Rep", comment: "Undo change cursor 10x rep suffix"),
        ]
    }

    // MARK: - KVO observation

    private static var propertiesContext = 0
    private static var cursorContext     = 0

    private func startObservingProperties() {
        for key in MCCursorLibrary.undoProperties().keys {
            addObserver(self, forKeyPath: key,
                        options: .old,
                        context: &MCCursorLibrary.propertiesContext)
        }
    }

    private func stopObservingProperties() {
        for key in MCCursorLibrary.undoProperties().keys {
            removeObserver(self, forKeyPath: key,
                           context: &MCCursorLibrary.propertiesContext)
        }
    }

    private func startObservingCursor(_ cursor: MCCursor) {
        for key in MCCursorLibrary.cursorUndoProperties().keys {
            cursor.addObserver(self, forKeyPath: key,
                               options: .old,
                               context: &MCCursorLibrary.cursorContext)
        }
    }

    private func stopObservingCursor(_ cursor: MCCursor) {
        for key in MCCursorLibrary.cursorUndoProperties().keys {
            cursor.removeObserver(self, forKeyPath: key,
                                  context: &MCCursorLibrary.cursorContext)
        }
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard context == &MCCursorLibrary.propertiesContext ||
              context == &MCCursorLibrary.cursorContext else { return }
        guard let keyPath = keyPath else { return }

        let decamelized: String?
        if context == &MCCursorLibrary.propertiesContext {
            decamelized = MCCursorLibrary.undoProperties()[keyPath]
        } else {
            decamelized = MCCursorLibrary.cursorUndoProperties()[keyPath]
        }

        var oldValue = change?[.oldKey]
        if oldValue is NSNull { oldValue = nil }

        (undoManager.prepare(withInvocationTarget: object as AnyObject) as AnyObject)
            .setValue(oldValue, forKeyPath: keyPath)

        if !undoManager.isUndoing, let desc = decamelized {
            let prefix = NSLocalizedString("Change ", comment: "Undo Change Prefix")
            undoManager.setActionName((prefix + desc).capitalized)
        }

        if keyPath == "identifier" {
            oldIdentifier = oldValue as? String
        }
    }

    // MARK: - Cursor management

    @objc func cursors(withIdentifier id: String) -> NSSet {
        let predicate = NSPredicate(format: "identifier == %@", id)
        return cursors.filtered(using: predicate) as NSSet
    }

    @objc func addCursor(_ cursor: MCCursor) {
        guard !cursors.contains(cursor) else { return }

        let change = NSSet(object: cursor)
        (undoManager.prepare(withInvocationTarget: self) as AnyObject).removeCursor(cursor)
        if !undoManager.isUndoing {
            undoManager.setActionName(NSLocalizedString("Add Cursor", comment: "Add Cursor Undo Title"))
        }

        willChangeValue(forKey: "cursors", withSetMutation: .union, using: change as Set<AnyHashable>)
        cursors.add(cursor)
        startObservingCursor(cursor)
        didChangeValue(forKey: "cursors", withSetMutation: .union, using: change as Set<AnyHashable>)
    }

    @objc func removeCursor(_ cursor: MCCursor) {
        let change = NSSet(object: cursor)
        (undoManager.prepare(withInvocationTarget: self) as AnyObject).addCursor(cursor)
        if !undoManager.isUndoing {
            undoManager.setActionName(NSLocalizedString("Remove Cursor", comment: "Remove Cursor Undo Title"))
        }

        willChangeValue(forKey: "cursors", withSetMutation: .minus, using: change as Set<AnyHashable>)
        cursors.remove(cursor)
        stopObservingCursor(cursor)
        didChangeValue(forKey: "cursors", withSetMutation: .minus, using: change as Set<AnyHashable>)
    }

    @objc func removeCursors(withIdentifier id: String) {
        for cursor in cursors(withIdentifier: id) {
            if let c = cursor as? MCCursor { removeCursor(c) }
        }
    }

    // MARK: - Serialisation

    @objc func dictionaryRepresentation() -> [String: Any] {
        var drep: [String: Any] = [
            MCCursorDictionaryMinimumVersionKey: 2.0,
            MCCursorDictionaryVersionKey:        2.0,
            MCCursorDictionaryCapeNameKey:       name,
            MCCursorDictionaryCapeVersionKey:    version,
            MCCursorDictionaryCloudKey:          isInCloud,
            MCCursorDictionaryAuthorKey:         author,
            MCCursorDictionaryHiDPIKey:          isHiDPI,
            MCCursorDictionaryIdentifierKey:     identifier,
        ]

        var cursorDicts: [String: Any] = [:]
        for case let cursor as MCCursor in cursors {
            cursorDicts[cursor.identifier] = cursor.dictionaryRepresentation()
        }
        drep[MCCursorDictionaryCursorsKey] = cursorDicts
        return drep
    }

    @objc @discardableResult
    func write(toFile file: String, atomically: Bool) -> Bool {
        return (dictionaryRepresentation() as NSDictionary).write(toFile: file, atomically: atomically)
    }

    @objc func save() -> NSError? {
        // Check for duplicate identifiers
        let allIdentifiers = (cursors.allObjects as! [MCCursor]).map { $0.identifier }
        let counted = NSCountedSet(array: allIdentifiers)
        var duplicateNames = Set<String>()
        for id in counted {
            if let idStr = id as? String, counted.count(for: id) > 1 {
                duplicateNames.insert(nameForCursorIdentifier(idStr))
            }
        }

        if !duplicateNames.isEmpty {
            return NSError(
                domain: MCErrorDomain,
                code: MCErrorCode.multipleCursorIdentifiers.rawValue,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("Save failed", comment: "New Cape Failure Title"),
                    NSLocalizedFailureReasonErrorKey: String(format:
                        NSLocalizedString("Multiple cursors with the name(s): %@ exist.",
                                          comment: "New Cape Failure Duplicate cursor name error"),
                        duplicateNames.joined(separator: ", ")),
                ])
        }

        NotificationCenter.default.post(name: NSNotification.Name(MCLibraryWillSaveNotificationName), object: self)

        guard let path = fileURL?.path, write(toFile: path, atomically: false) else {
            return NSError(
                domain: MCErrorDomain,
                code: MCErrorCode.writeFail.rawValue,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("Save failed", comment: "New Cape Failure Title"),
                    NSLocalizedFailureReasonErrorKey: NSLocalizedString("Error writing cape to disk.", comment: ""),
                ])
        }

        updateChangeCount(.changeCleared)
        NotificationCenter.default.post(name: NSNotification.Name(MCLibraryDidSaveNotificationName), object: self)
        return nil
    }

    // MARK: - Change count

    @objc func updateChangeCount(_ change: NSDocument.ChangeType) {
        switch change {
        case .changeDone, .changeRedone:
            changeCount += 1
        case .changeUndone:
            if changeCount > 0 { changeCount -= 1 }
        case .changeCleared, .changeAutosaved:
            lastChangeCount = changeCount
        default:
            break
        }
    }

    @objc func revertToSaved() {
        while isDirty { undoManager.undo() }
        updateChangeCount(.changeCleared)
        undoManager.removeAllActions()
    }

    // MARK: - Private reading

    private func readFromDictionary(_ dict: [String: Any]) -> Bool {
        guard !dict.isEmpty else {
            NSLog("Cannot make library from empty dictionary")
            return false
        }

        for case let cursor as MCCursor in cursors { stopObservingCursor(cursor) }
        cursors = NSMutableSet()
        undoManager.disableUndoRegistration()

        let minimumVersion = (dict[MCCursorDictionaryMinimumVersionKey] as? NSNumber)?.doubleValue ?? 0
        let version        = (dict[MCCursorDictionaryVersionKey] as? NSNumber)?.doubleValue ?? 0
        let cursorDicts    = dict[MCCursorDictionaryCursorsKey] as? [String: Any]
        let cloud          = (dict[MCCursorDictionaryCloudKey] as? NSNumber)?.boolValue ?? false
        let authorStr      = dict[MCCursorDictionaryAuthorKey] as? String
        let hiDPI          = (dict[MCCursorDictionaryHiDPIKey] as? NSNumber)?.boolValue ?? false
        let identifierStr  = dict[MCCursorDictionaryIdentifierKey] as? String
        let capeNameStr    = dict[MCCursorDictionaryCapeNameKey] as? String
        let capeVersionNum = dict[MCCursorDictionaryCapeVersionKey] as? NSNumber

        name           = capeNameStr ?? name
        self.version   = capeVersionNum ?? self.version
        author         = authorStr ?? author
        identifier     = identifierStr ?? identifier
        isHiDPI        = hiDPI
        isInCloud      = cloud

        guard identifierStr != nil else {
            NSLog("Cannot make library from dictionary with no identifier")
            undoManager.enableUndoRegistration()
            return false
        }

        if minimumVersion > Double(MCCursorParserVersion) {
            undoManager.enableUndoRegistration()
            return false
        }

        cursors.removeAllObjects()
        addCursors(fromDictionary: cursorDicts ?? [:], ofVersion: CGFloat(version))
        undoManager.enableUndoRegistration()
        return true
    }

    private func addCursors(fromDictionary dict: [String: Any], ofVersion version: CGFloat) {
        for (key, value) in dict {
            guard let cursorDict = value as? [String: Any],
                  let cursor = MCCursor(cursorDictionary: cursorDict, ofVersion: version) else { continue }
            cursor.identifier = key
            addCursor(cursor)
        }
    }

    // MARK: - Equality

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MCCursorLibrary else { return false }
        return other.name       == name &&
               other.author     == author &&
               other.identifier == identifier &&
               other.version    == version &&
               other.isInCloud  == isInCloud &&
               other.isHiDPI    == isHiDPI &&
               other.cursors.isEqual(cursors)
    }
}
