// MCEditWindowController.swift
// Mousecape
//
// Swift replacement for MCEditWindowController.h / .m

import AppKit

@objc(MCEditWindowController) class MCEditWindowController: NSWindowController,
    NSWindowDelegate, NSSplitViewDelegate {

    @IBOutlet var editListController: MCEditListController?
    @IBOutlet var editDetailController: MCEditDetailController?
    @IBOutlet var editCapeController: MCEditCapeController?
    @IBOutlet var detailView: NSView?

    private static var cursorLibraryContext = 0

    // MARK: - cursorLibrary (dynamic, backed by editListController)

    @objc dynamic var cursorLibrary: MCCursorLibrary? {
        get { return editListController?.cursorLibrary }
        set { promptSave(forNextLibrary: newValue) }
    }

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "cursorLibrary" {
            return ["editListController.cursorLibrary"]
        }
        return super.keyPathsForValuesAffectingValue(forKey: key)
    }

    // MARK: - Init

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Window lifecycle

    override func windowDidLoad() {
        super.windowDidLoad()
        editListController?.addObserver(self, forKeyPath: "selectedObject", options: [], context: nil)
        setCurrentViewController(editCapeController)
        window?.bind(NSBindingName("documentEdited"),
                     to: self, withKeyPath: "cursorLibrary.dirty",
                     options: nil)
    }

    deinit {
        editListController?.removeObserver(self, forKeyPath: "selectedObject")
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == "selectedObject" {
            changeEditViewsForSelection()
        }
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return !promptSave(forNextLibrary: nil)
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        return cursorLibrary?.undoManager
    }

    // MARK: - Save prompt (replaces NSBeginAlertSheet)

    @discardableResult
    private func promptSave(forNextLibrary nextLibrary: MCCursorLibrary?) -> Bool {
        guard window?.isDocumentEdited == true else {
            editListController?.cursorLibrary = nextLibrary
            return false
        }

        let alert = NSAlert()
        alert.messageText     = NSLocalizedString("Do you want to save your changes?",
                                                  comment: "Save Prompt Title")
        alert.informativeText = NSLocalizedString("Your changes will be discarded if you don't save them.",
                                                  comment: "Save prompt threat")
        alert.addButton(withTitle: NSLocalizedString("Save",           comment: "Save Prompt Button"))
        alert.addButton(withTitle: NSLocalizedString("Cancel",         comment: "Save Prompt Button"))
        alert.addButton(withTitle: NSLocalizedString("Discard Changes",comment: "Save Prompt Button"))

        guard let win = window else { return true }
        alert.beginSheetModal(for: win) { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .alertFirstButtonReturn:  // Save
                if let error = self.cursorLibrary?.save() {
                    NSApp.presentError(error, modalFor: win, delegate: nil,
                                       didPresent: nil, contextInfo: nil)
                } else {
                    self.editListController?.cursorLibrary = nextLibrary
                    if nextLibrary == nil { self.window?.close() }
                }
            case .alertThirdButtonReturn:  // Discard
                self.cursorLibrary?.revertToSaved()
                self.editListController?.cursorLibrary = nextLibrary
                if nextLibrary == nil { self.window?.close() }
            default: // Cancel – do nothing
                break
            }
        }
        return true
    }

    // MARK: - Menu Actions

    @IBAction func applyCape(_ sender: Any) {
        guard let lib = cursorLibrary else { return }
        lib.library?.applyCape(lib)
    }

    @IBAction func duplicateCape(_ sender: Any) {
        guard let copy = cursorLibrary?.copy() as? MCCursorLibrary else { return }
        cursorLibrary?.library?.importCape(copy)
    }

    @IBAction func checkCape(_ sender: Any) { }

    @IBAction func saveDocument(_ sender: Any) {
        guard let error = cursorLibrary?.save() else { return }
        presentError(error, modalFor: window!, delegate: nil,
                     didPresent: nil, contextInfo: nil)
    }

    @IBAction func revertDocumentToSaved(_ sender: Any) {
        cursorLibrary?.revertToSaved()
    }

    @IBAction func showCape(_ sender: Any) {
        if let url = cursorLibrary?.fileURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    override func willPresentError(_ error: Error) -> Error {
        let nse = error as NSError
        return NSError(
            domain: nse.domain,
            code: nse.code,
            userInfo: [
                NSLocalizedDescriptionKey: nse.localizedDescription,
                NSLocalizedRecoverySuggestionErrorKey: nse.localizedFailureReason ?? "",
            ])
    }

    // MARK: - View changing

    private func changeEditViewsForSelection() {
        if let library = editListController?.selectedObject as? MCCursorLibrary {
            setCurrentViewController(editCapeController)
            editCapeController?.cursorLibrary = library
        } else if let cursor = editListController?.selectedObject as? MCCursor {
            setCurrentViewController(editDetailController)
            editDetailController?.cursor = cursor
        }
    }

    private func setCurrentViewController(_ vc: NSViewController?) {
        guard let vc = vc, let detailView = detailView else { return }
        guard !detailView.subviews.contains(vc.view) else { return }

        detailView.subviews = []
        detailView.removeConstraints(detailView.constraints)

        vc.view.frame = detailView.bounds
        vc.view.translatesAutoresizingMaskIntoConstraints = true
        vc.view.autoresizingMask = [.height, .width, .minYMargin, .minXMargin]
        detailView.addSubview(vc.view)
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return false
    }

    func splitView(_ splitView: NSSplitView,
                   constrainMinCoordinate proposedMin: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        return dividerIndex == 0 ? 120.0 : proposedMin
    }

    func splitView(_ splitView: NSSplitView,
                   constrainMaxCoordinate proposedMax: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        return dividerIndex == 0 ? splitView.frame.size.width - 380.0 : proposedMax
    }
}
