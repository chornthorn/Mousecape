// MCEditListController.swift
// Mousecape
//
// Swift replacement for MCEditListController.h / .m

import AppKit

@objc(MCEditListController) class MCEditListController: NSViewController,
    NSTableViewDataSource, NSTableViewDelegate {

    @objc dynamic var cursorLibrary: MCCursorLibrary? {
        didSet { }
    }
    @objc dynamic weak var selectedObject: AnyObject?

    @IBOutlet var tableView: NSTableView?

    private var cursors: NSMutableOrderedSet = NSMutableOrderedSet()

    private static var cursorsContext  = 0
    private static var nameContext     = 0

    // MARK: - Init

    override init(nibName: NSNib.Name?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addObserver(self,
                    forKeyPath: "cursorLibrary.cursors",
                    options: [.old, .new],
                    context: &MCEditListController.cursorsContext)
    }

    deinit {
        removeObserver(self, forKeyPath: "cursorLibrary.cursors",
                       context: &MCEditListController.cursorsContext)
        for case let cursor as MCCursor in cursors {
            stopObservingCursor(cursor)
        }
    }

    // MARK: - Cursor KVO

    private func startObservingCursor(_ cursor: MCCursor) {
        cursor.addObserver(self, forKeyPath: "name", options: [],
                           context: &MCEditListController.nameContext)
    }

    private func stopObservingCursor(_ cursor: MCCursor) {
        cursor.removeObserver(self, forKeyPath: "name",
                              context: &MCEditListController.nameContext)
    }

    // MARK: - Sort comparator

    private static let sortComparator: (Any, Any) -> ComparisonResult = { a, b in
        let nameA = (a as? MCCursor)?.name ?? ""
        let nameB = (b as? MCCursor)?.name ?? ""
        return nameA.localizedCaseInsensitiveCompare(nameB)
    }

    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if context == &MCEditListController.cursorsContext {
            let kind = NSKeyValueChange(rawValue: (change?[.kindKey] as? UInt) ?? 0) ?? .setting
            tableView?.beginUpdates()
            defer { tableView?.endUpdates() }

            switch kind {
            case .setting:
                let nextSet = change?[.newKey]
                if nextSet is NSNull || nextSet == nil {
                    cursors = NSMutableOrderedSet()
                } else if let set = nextSet as? NSSet {
                    cursors = NSMutableOrderedSet(set: set, copyItems: false)
                    cursors.sort(comparator: MCEditListController.sortComparator)
                    for case let cursor as MCCursor in cursors { startObservingCursor(cursor) }
                }
                tableView?.reloadData()
                tableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

            case .insertion:
                guard let newItems = change?[.newKey] as? NSSet else { break }
                for case let cursor as MCCursor in newItems {
                    let index = cursors.indexForInsertingObject(cursor,
                        sortedUsingComparator: MCEditListController.sortComparator)
                    willChange(.insertion, valuesAt: IndexSet(integer: index), forKey: "cursors")
                    cursors.insert(cursor, at: index)
                    startObservingCursor(cursor)
                    didChange(.insertion, valuesAt: IndexSet(integer: index), forKey: "cursors")
                    tableView?.insertRows(at: IndexSet(integer: index + 1), withAnimation: .slideUp)
                }

            case .removal:
                guard let oldItems = change?[.oldKey] as? NSSet else { break }
                for case let cursor as MCCursor in oldItems {
                    let index = cursors.index(of: cursor)
                    guard index != NSNotFound else { continue }
                    willChange(.removal, valuesAt: IndexSet(integer: index), forKey: "cursors")
                    stopObservingCursor(cursor)
                    cursors.removeObject(at: index)
                    didChange(.removal, valuesAt: IndexSet(integer: index), forKey: "cursors")
                    tableView?.removeRows(at: IndexSet(integer: index + 1),
                                          withAnimation: [.slideUp, .effectFade])
                }

            default: break
            }
        } else if context == &MCEditListController.nameContext {
            guard let cursor = object as? MCCursor else { return }
            let oldIndex = cursors.index(of: cursor)
            guard oldIndex != NSNotFound else { return }
            cursors.removeObject(at: oldIndex)
            let newIndex = cursors.indexForInsertingObject(cursor,
                sortedUsingComparator: MCEditListController.sortComparator)
            cursors.insert(cursor, at: newIndex)
            tableView?.moveRow(at: oldIndex + 1, to: newIndex + 1)
        }
    }

    // MARK: - IBActions

    @IBAction func addAction(_ sender: Any) {
        cursorLibrary?.addCursor(MCCursor())
    }

    @IBAction func removeAction(_ sender: NSMenuItem) {
        let row = sender.tag == -1 ? (tableView?.clickedRow ?? 0) : (tableView?.selectedRow ?? 0)
        guard row > 0,
              let cell = tableView?.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
              let cursor = cell.objectValue as? MCCursor else { return }
        cursorLibrary?.removeCursor(cursor)
    }

    @IBAction func duplicateAction(_ sender: NSMenuItem) {
        let row = sender.tag == -1 ? (tableView?.clickedRow ?? 0) : (tableView?.selectedRow ?? 0)
        guard row > 0,
              let cell = tableView?.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
              let cursor = (cell.objectValue as? MCCursor)?.copy() as? MCCursor else { return }
        cursor.identifier = Foundation.UUID().uuidString
        cursorLibrary?.addCursor(cursor)
    }

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tv = tableView else { return }
        let row = tv.selectedRow
        guard row != NSNotFound, row < cursors.count + 1 else { return }
        selectedObject = row == 0 ? cursorLibrary : cursors.object(at: row - 1) as AnyObject
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool { return row == 0 }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return row == 0 ? 32.0 : 22.0
    }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let id: NSUserInterfaceItemIdentifier = row == 0
            ? NSUserInterfaceItemIdentifier("MCCursorLibrary")
            : NSUserInterfaceItemIdentifier("MCCursor")
        return tableView.makeView(withIdentifier: id, owner: self)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return cursors.count + 1
    }

    func tableView(_ tableView: NSTableView,
                   objectValueFor tableColumn: NSTableColumn?,
                   row: Int) -> Any? {
        return row == 0 ? cursorLibrary : cursors.object(at: row - 1)
    }
}
