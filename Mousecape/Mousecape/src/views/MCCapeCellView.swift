// MCCapeCellView.swift
// Mousecape
//
// Swift replacement for MCCapeCellView.h / MCCapeCellView.m

import AppKit

@objc(MCCapeCellView) class MCCapeCellView: NSTableCellView {

    @IBOutlet var titleField: NSTextField?
    @IBOutlet var subtitleField: NSTextField?
    @IBOutlet var appliedImageView: NSImageView?
    @IBOutlet var resolutionImageView: NSImageView?
    @IBOutlet var collectionView: NSCollectionView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let cv = collectionView else { return }

        let prototype = MCCapePreviewItem()
        cv.itemPrototype = prototype
        cv.bind(NSBindingName(rawValue: NSBindingName.content.rawValue),
                to: self,
                withKeyPath: "objectValue.cursors",
                options: [.valueTransformer: MCSortValueTransformer()])

        cv.minItemSize = prototype.view.frame.size
        cv.maxItemSize = prototype.view.frame.size
    }

    deinit {
        collectionView?.unbind(NSBindingName(rawValue: NSBindingName.content.rawValue))
    }
}

// MARK: - MCSortValueTransformer (private)

private class MCSortValueTransformer: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSArray.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let set = value as? NSSet else { return nil }
        return set.sortedArray(using: [
            NSSortDescriptor(key: "name", ascending: true,
                             selector: #selector(NSString.caseInsensitiveCompare(_:))),
        ])
    }
}

// MARK: - MCHDValueTransformer

@objc(MCHDValueTransformer) class MCHDValueTransformer: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSImage.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        let isHiDPI = (value as? NSNumber)?.boolValue ?? false
        let name: NSImage.Name = isHiDPI ? "HDTemplate" : "SDTemplate"
        let image = NSImage(named: name)
        image?.isTemplate = true
        return image
    }
}
