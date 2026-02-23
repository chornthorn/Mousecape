// MCLibraryViewController.swift
// Mousecape
//
// Swift replacement for MCLibraryViewController.h / .m + MCLibraryController (Properties) extension

import AppKit

// MARK: - MCLibraryController ordered-capes extension (used by this view controller)

extension MCLibraryController {
    @objc var orderedCapes: NSOrderedSet {
        let sorted = capes.sortedArray(using: [
            NSSortDescriptor(key: "name",   ascending: true,
                             selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
            NSSortDescriptor(key: "author", ascending: true,
                             selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
        ])
        return NSOrderedSet(array: sorted)
    }
}

// MARK: - MCLibraryViewController

@objc(MCLibraryViewController) class MCLibraryViewController: NSViewController,
    NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet var contextMenu: NSMenu?
    @IBOutlet var tableView: NSTableView?

    @objc private(set) var libraryController: MCLibraryController!
    @objc dynamic weak var editingCape: MCCursorLibrary? { return editWindowController?.cursorLibrary }
    @objc dynamic weak var selectedCape: MCCursorLibrary? {
        guard let row = tableView?.selectedRow, row >= 0 else { return nil }
        return cellView(at: row)?.objectValue as? MCCursorLibrary
    }
    @objc dynamic weak var clickedCape: MCCursorLibrary? {
        guard let row = tableView?.clickedRow, row >= 0 else { return nil }
        return cellView(at: row)?.objectValue as? MCCursorLibrary
    }

    private var editWindowController: MCEditWindowController?
    private var capes: NSMutableOrderedSet = NSMutableOrderedSet()

    private static var capesContext = 0
    private static var nameContext  = 0

    // MARK: - Sort comparator

    private static let sortComparator: (Any, Any) -> ComparisonResult = { a, b in
        let lib1 = a as? MCCursorLibrary
        let lib2 = b as? MCCursorLibrary
        let byName = (lib1?.name ?? "").localizedCaseInsensitiveCompare(lib2?.name ?? "")
        if byName != .orderedSame { return byName }
        return (lib1?.author ?? "").localizedCaseInsensitiveCompare(lib2?.author ?? "")
    }

    // MARK: - Init

    override init(nibName: NSNib.Name?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        setupEnvironment()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupEnvironment()
    }

    deinit {
        libraryController?.removeObserver(self, forKeyPath: "appliedCape")
        for case let lib as MCCursorLibrary in capes {
            lib.removeObserver(self, forKeyPath: "name",
                               context: &MCLibraryViewController.nameContext)
        }
        removeObserver(self, forKeyPath: "libraryController.capes",
                       context: &MCLibraryViewController.capesContext)
    }

    private static func capesPath() -> String {
        var error: NSError?
        return FileManager.default.findOrCreateDirectory(
            .applicationSupportDirectory,
            inDomain: .userDomainMask,
            appendPathComponent: "Mousecape/capes",
            error: &error) ?? ""
    }

    private func setupEnvironment() {
        addObserver(self,
                    forKeyPath: "libraryController.capes",
                    options: [.new, .old],
                    context: &MCLibraryViewController.capesContext)
        libraryController = MCLibraryController(
            url: URL(fileURLWithPath: MCLibraryViewController.capesPath()))
        representedObject = libraryController
        libraryController.addObserver(self, forKeyPath: "appliedCape", options: [], context: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        tableView?.doubleAction = #selector(doubleClick(_:))
        tableView?.target       = self
    }

    // MARK: - KVO

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "editingCape" { return ["editWindowController.cursorLibrary"] }
        return super.keyPathsForValuesAffectingValue(forKey: key)
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == "appliedCape" {
            for row in 0..<(tableView?.numberOfRows ?? 0) {
                if let cv = cellView(at: row) {
                    cv.appliedImageView?.isHidden = !(cv.objectValue as? MCCursorLibrary === libraryController.appliedCape)
                }
            }
            return
        }

        if context == &MCLibraryViewController.capesContext {
            let kind = NSKeyValueChange(rawValue: (change?[.kindKey] as? UInt) ?? 0) ?? .setting
            tableView?.beginUpdates()
            defer { tableView?.endUpdates() }

            switch kind {
            case .setting, .insertion:
                if kind == .setting { capes = NSMutableOrderedSet() }
                guard let newItems = change?[.newKey] as? NSSet else { break }
                for case let lib as MCCursorLibrary in newItems {
                    let index = capes.indexForInsertingObject(lib,
                        sortedUsingComparator: MCLibraryViewController.sortComparator)
                    willChange(.insertion, valuesAt: IndexSet(integer: index), forKey: "capes")
                    lib.addObserver(self, forKeyPath: "name", options: [],
                                    context: &MCLibraryViewController.nameContext)
                    capes.insert(lib, at: index)
                    didChange(.insertion, valuesAt: IndexSet(integer: index), forKey: "capes")
                    tableView?.insertRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                }

            case .removal:
                guard let oldItems = change?[.oldKey] as? NSSet else { break }
                for case let lib as MCCursorLibrary in oldItems {
                    let index = capes.index(of: lib)
                    guard index != NSNotFound else { continue }
                    willChange(.removal, valuesAt: IndexSet(integer: index), forKey: "capes")
                    lib.removeObserver(self, forKeyPath: "name",
                                       context: &MCLibraryViewController.nameContext)
                    capes.removeObject(at: index)
                    didChange(.removal, valuesAt: IndexSet(integer: index), forKey: "capes")
                    tableView?.removeRows(at: IndexSet(integer: index),
                                          withAnimation: [.slideUp, .effectFade])
                    if editWindowController?.cursorLibrary === lib {
                        editWindowController?.cursorLibrary = nil
                        editWindowController?.close()
                    }
                }

            default: break
            }
            return
        }

        if context == &MCLibraryViewController.nameContext {
            guard let cape = object as? MCCursorLibrary else { return }
            let oldIndex = capes.index(of: cape)
            guard oldIndex != NSNotFound else { return }
            capes.removeObject(at: oldIndex)
            let newIndex = capes.indexForInsertingObject(cape,
                sortedUsingComparator: MCLibraryViewController.sortComparator)
            capes.insert(cape, at: newIndex)
            tableView?.moveRow(at: oldIndex, to: newIndex)
            return
        }

        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }

    // MARK: - Actions

    @objc private func doubleClick(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0,
              let lib = (sender.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView)?
                .objectValue as? MCCursorLibrary else { return }

        if UserDefaults.standard.integer(forKey: MCPreferencesDoubleActionKey) == 0 {
            libraryController.applyCape(lib)
        } else {
            editCape(lib)
        }
    }

    @objc func editCape(_ library: MCCursorLibrary) {
        if editWindowController == nil {
            editWindowController = MCEditWindowController(windowNibName: "Edit")
            editWindowController?.loadWindow()
        }
        editWindowController?.cursorLibrary = library
        editWindowController?.showWindow(self)
    }

    // MARK: - Helpers

    private func cellView(at row: Int) -> NSTableCellView? {
        return tableView?.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { return capes.count }

    func tableView(_ tableView: NSTableView,
                   objectValueFor tableColumn: NSTableColumn?,
                   row: Int) -> Any? {
        return capes[row]
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        guard let id = tableColumn?.identifier else { return nil }
        let cell = tableView.makeView(withIdentifier: id, owner: self) as? MCCapeCellView
        cell?.appliedImageView?.isHidden = !(capes[row] as? MCCursorLibrary === libraryController.appliedCape)
        return cell
    }
}
