// MCLibraryWindowController.swift
// Mousecape
//
// Swift replacement for MCLibraryWindowController.h / .m

import AppKit

@objc(MCLibraryWindowController) class MCLibraryWindowController: NSWindowController, NSWindowDelegate {

    @IBOutlet weak var libraryViewController: MCLibraryViewController?
    @IBOutlet weak var appliedAccessory: NSView?
    @IBOutlet weak var progressBar: NSProgressIndicator?
    @IBOutlet weak var progressField: NSTextField?

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        composeAccessory()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        NSLog("window load")
        composeAccessory()
    }

    override var windowNibName: NSNib.Name? { return "Library" }

    // MARK: - Accessory

    private func composeAccessory() {
        guard let accessory = appliedAccessory,
              let themeFrame = window?.contentView?.superview else { return }

        accessory.translatesAutoresizingMaskIntoConstraints = false

        let c  = themeFrame.frame
        let aV = accessory.frame
        accessory.frame = NSRect(
            x: c.size.width  - aV.size.width,
            y: c.size.height - aV.size.height,
            width: aV.size.width,
            height: aV.size.height)
        themeFrame.addSubview(accessory)

        let views = ["accessory": accessory]
        themeFrame.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "H:|-(>=100)-[accessory(245)]-(0)-|",
            options: [], metrics: nil, views: views))
        themeFrame.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|-(0)-[accessory(20)]-(>=22)-|",
            options: [], metrics: nil, views: views))
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        return libraryViewController?.libraryController?.undoManager
    }

    // MARK: - Menu Actions

    @IBAction func applyCapeAction(_ sender: NSMenuItem) {
        let cape = sender.tag == -1 ? libraryViewController?.clickedCape
                                    : libraryViewController?.selectedCape
        guard let c = cape else { return }
        libraryViewController?.libraryController?.applyCape(c)
    }

    @IBAction func editCapeAction(_ sender: NSMenuItem) {
        let cape = sender.tag == -1 ? libraryViewController?.clickedCape
                                    : libraryViewController?.selectedCape
        guard let c = cape else { return }
        libraryViewController?.editCape(c)
    }

    @IBAction func removeCapeAction(_ sender: NSMenuItem) {
        let cape = sender.tag == -1 ? libraryViewController?.clickedCape
                                    : libraryViewController?.selectedCape
        guard let c = cape else { return }

        if c !== libraryViewController?.editingCape {
            libraryViewController?.libraryController?.removeCape(c)
        } else {
            NSSound(named: "Funk")?.play()
            if let editing = libraryViewController?.editingCape {
                libraryViewController?.editCape(editing)
            }
        }
    }

    @IBAction func duplicateCapeAction(_ sender: NSMenuItem) {
        let cape = sender.tag == -1 ? libraryViewController?.clickedCape
                                    : libraryViewController?.selectedCape
        guard let c = cape?.copy() as? MCCursorLibrary else { return }
        libraryViewController?.libraryController?.importCape(c)
    }

    @IBAction func checkCapeAction(_ sender: NSMenuItem) { }

    @IBAction func showCapeAction(_ sender: NSMenuItem) {
        let cape = sender.tag == -1 ? libraryViewController?.clickedCape
                                    : libraryViewController?.selectedCape
        guard let url = cape?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @IBAction func dumpCapeAction(_ sender: NSMenuItem) {
        guard let sheet = progressBar?.window else { return }
        window?.beginSheet(sheet, completionHandler: nil)
        progressBar?.doubleValue = 0.0
        progressBar?.isIndeterminate = false

        weak var weakSelf = self
        DispatchQueue.global(qos: .background).async {
            weakSelf?.libraryViewController?.libraryController?.dumpCursors(withProgressBlock: { current, total in
                DispatchQueue.main.sync {
                    let ofStr = NSLocalizedString("of", comment: "Dump cursor progress separator (eg: 5 of 129)")
                    weakSelf?.progressField?.stringValue = "\(current) \(ofStr) \(total)"
                    weakSelf?.progressBar?.minValue    = 0
                    weakSelf?.progressBar?.maxValue    = Double(total)
                    weakSelf?.progressBar?.doubleValue = Double(current)
                }
                return true
            })

            DispatchQueue.main.sync {
                if let sheet = weakSelf?.progressBar?.window {
                    weakSelf?.window?.endSheet(sheet)
                }
                NSCursor.arrow.set()
            }
        }
    }
}

// MARK: - MCAppliedCapeValueTransformer

@objc(MCAppliedCapeValueTransformer) class MCAppliedCapeValueTransformer: ValueTransformer {

    override class func transformedValueClass() -> AnyClass { return NSString.self }

    override func transformedValue(_ value: Any?) -> Any? {
        let appliedLabel = NSLocalizedString("Applied Cape: ",
                                             comment: "Accessory label for applied cape")
        let capeName = (value as? String) ??
            NSLocalizedString("None", comment: "Window Titlebar Accessory label for when no cape is applied")
        return appliedLabel + capeName
    }
}
