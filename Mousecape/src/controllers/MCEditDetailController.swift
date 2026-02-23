// MCEditDetailController.swift
// Mousecape
//
// Swift replacement for MCEditDetailController.h / .m

import AppKit

@objc(MCEditDetailController) class MCEditDetailController: NSViewController, MMAnimatingImageViewDelegate {

    @objc var cursor: MCCursor?

    @IBOutlet var typePopUpButton: NSPopUpButton?
    @IBOutlet var rep100View: MMAnimatingImageView?
    @IBOutlet var rep200View: MMAnimatingImageView?
    @IBOutlet var rep500View: MMAnimatingImageView?
    @IBOutlet var rep1000View: MMAnimatingImageView?

    override func awakeFromNib() {
        super.awakeFromNib()

        let sortedNames = cursorNameMap.values.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        typePopUpButton?.addItems(withTitles: sortedNames)

        let dropzone = NSImage(named: "dropzone")
        rep100View?.placeholderImage  = dropzone
        rep200View?.placeholderImage  = dropzone
        rep500View?.placeholderImage  = dropzone
        rep1000View?.placeholderImage = dropzone

        rep100View?.scale  = 1.0
        rep200View?.scale  = 2.0
        rep500View?.scale  = 5.0
        rep1000View?.scale = 10.0

        bindRepView(rep100View,  suffix: "100")
        bindRepView(rep200View,  suffix: "200")
        bindRepView(rep500View,  suffix: "500")
        bindRepView(rep1000View, suffix: "1000")
    }

    private func bindRepView(_ view: MMAnimatingImageView?, suffix: String) {
        guard let view = view else { return }
        view.bind(NSBindingName("image"),         to: self, withKeyPath: "cursor.cursorImage\(suffix)", options: nil)
        view.bind(NSBindingName("frameCount"),    to: self, withKeyPath: "cursor.frameCount",           options: nil)
        view.bind(NSBindingName("frameDuration"), to: self, withKeyPath: "cursor.frameDuration",        options: nil)
        view.bind(NSBindingName("hotSpot"),       to: self, withKeyPath: "cursor.hotSpot",              options: nil)
    }

    // MARK: - MMAnimatingImageViewDelegate

    func imageView(_ imageView: MMAnimatingImageView,
                   draggingEntered drop: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func imageView(_ imageView: MMAnimatingImageView,
                   shouldPrepareForDragOperation drop: NSDraggingInfo) -> Bool { return true }

    func imageView(_ imageView: MMAnimatingImageView,
                   shouldPerformDragOperation drop: NSDraggingInfo) -> Bool { return true }

    func imageView(_ imageView: MMAnimatingImageView, didAcceptDroppedImages images: [NSImageRep]) {
        guard let cursor = cursor else { return }
        let scale = cursorScaleForScale(imageView.scale)

        if NSEvent.modifierFlags == .option {
            if let composed = MCCursor.composeRepresentation(withFrames: images) {
                cursor.addFrame(composed, forScale: scale)
            }
        } else {
            cursor.setRepresentation(MCCursor.composeRepresentation(withFrames: images), forScale: scale)
            cursor.frameCount = images.count
        }
    }

    func imageView(_ imageView: MMAnimatingImageView, didDragOutImage image: NSImage) {
        cursor?.setRepresentation(nil, forScale: cursorScaleForScale(imageView.scale))
    }
}

// MARK: - MCCursorTypeValueTransformer

@objc(MCCursorTypeValueTransformer) class MCCursorTypeValueTransformer: ValueTransformer {

    override class func transformedValueClass() -> AnyClass { return NSString.self }

    override class func allowsReverseTransformation() -> Bool { return true }

    override func transformedValue(_ value: Any?) -> Any? {
        return nameForCursorIdentifier(value as? String ?? "")
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return cursorIdentifierForName(value as? String ?? "")
    }
}
