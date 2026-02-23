// MMAnimatingImageView.swift
// Mousecape
//
// Swift replacement for MMAnimatingImageView.h / MMAnimatingImageView.m

import AppKit
import QuartzCore

// MARK: - Delegate protocol

@objc protocol MMAnimatingImageViewDelegate: NSObjectProtocol {
    func imageView(_ imageView: MMAnimatingImageView, draggingEntered drop: NSDraggingInfo) -> NSDragOperation
    func imageView(_ imageView: MMAnimatingImageView, shouldPrepareForDragOperation drop: NSDraggingInfo) -> Bool
    func imageView(_ imageView: MMAnimatingImageView, shouldPerformDragOperation drop: NSDraggingInfo) -> Bool
    func imageView(_ imageView: MMAnimatingImageView, didAcceptDroppedImages images: [NSImageRep])
    func imageView(_ imageView: MMAnimatingImageView, didDragOutImage image: NSImage)
}

// MARK: - MMAnimatingImageView

@objc(MMAnimatingImageView) class MMAnimatingImageView: NSView,
    NSDraggingDestination, NSDraggingSource, NSPasteboardItemDataProvider {

    // MARK: Public properties

    @objc dynamic var image: NSImage? {
        didSet { spriteLayer?.contents = image ?? placeholderImage }
    }
    @objc dynamic var placeholderImage: NSImage? {
        didSet { spriteLayer?.contents = image ?? placeholderImage }
    }
    @objc dynamic var frameDuration: CGFloat = 1.0
    @objc dynamic var frameCount: Int = 1
    @objc dynamic var scale: CGFloat = 0.0
    @objc dynamic var hotSpot: NSPoint = .zero
    @objc dynamic var shouldFlipHorizontally: Bool = false
    @IBOutlet weak var delegate: MMAnimatingImageViewDelegate?
    @objc dynamic var shouldAnimate: Bool = true
    @objc dynamic var shouldAllowDragging: Bool = false

    @objc var shouldShowHotSpot: Bool {
        get { return !(hotSpotLayer?.isHidden ?? true) }
        set { hotSpotLayer?.isHidden = !newValue }
    }

    // MARK: Private

    private weak var spriteLayer: MCSpriteLayer?
    private weak var hotSpotLayer: CALayer?

    private static var invalidateContext = 0

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        initialize()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    private func initialize() {
        shouldAnimate = true
        registerForDraggedTypes([.tiff, NSPasteboard.PasteboardType("NSFilenamesPboardType")])

        let sprite = MCSpriteLayer()
        self.layer = sprite
        wantsLayer = true
        layer?.contentsGravity = .center
        layer?.bounds = bounds
        layer?.autoresizingMask = [.layerHeightSizable, .layerWidthSizable,
                                   .layerMinXMargin, .layerMinYMargin]
        layer?.delegate = self

        let hs = CALayer()
        hs.bounds            = CGRect(x: 0, y: 0, width: 3, height: 3)
        hs.backgroundColor   = NSColor.red.cgColor
        hs.autoresizingMask  = []
        hs.anchorPoint       = CGPoint(x: 0.5, y: 0.5)
        hs.borderColor       = NSColor.black.cgColor
        hs.borderWidth       = 0.5
        layer?.addSublayer(hs)
        hotSpotLayer = hs

        spriteLayer = sprite

        shouldShowHotSpot    = false
        shouldAllowDragging  = false
        frameCount           = 1
        frameDuration        = 1.0

        addObserver(self, forKeyPath: "image",              options: [], context: &MMAnimatingImageView.invalidateContext)
        addObserver(self, forKeyPath: "hotSpot",            options: [], context: &MMAnimatingImageView.invalidateContext)
        addObserver(self, forKeyPath: "placeholderImage",   options: [], context: &MMAnimatingImageView.invalidateContext)
        addObserver(self, forKeyPath: "frameCount",         options: [], context: &MMAnimatingImageView.invalidateContext)
        addObserver(self, forKeyPath: "frameDuration",      options: [], context: &MMAnimatingImageView.invalidateContext)
        addObserver(self, forKeyPath: "shouldAnimate",      options: [], context: nil)
        addObserver(self, forKeyPath: "shouldFlipHorizontally", options: [], context: nil)
    }

    deinit {
        removeObserver(self, forKeyPath: "image")
        removeObserver(self, forKeyPath: "hotSpot")
        removeObserver(self, forKeyPath: "placeholderImage")
        removeObserver(self, forKeyPath: "frameCount")
        removeObserver(self, forKeyPath: "frameDuration")
        removeObserver(self, forKeyPath: "shouldAnimate")
        removeObserver(self, forKeyPath: "shouldFlipHorizontally")
    }

    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if context == &MMAnimatingImageView.invalidateContext {
            if keyPath == "image" || keyPath == "placeholderImage" {
                spriteLayer?.contents = image ?? placeholderImage
            }
            invalidateFrame()
            invalidateAnimation()
        } else if keyPath == "shouldAnimate" {
            invalidateAnimation()
        } else if keyPath == "shouldFlipHorizontally" {
            resetTransform()
        }
    }

    // MARK: - CALayerDelegate

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        return false
    }

    // MARK: - View lifecycle

    override func viewDidMoveToWindow() {
        invalidateFrame()
    }

    // MARK: - KVO key paths affecting shouldShowHotSpot

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "shouldShowHotSpot" {
            return ["hotSpotLayer.hidden"]
        }
        return super.keyPathsForValuesAffectingValue(forKey: key)
    }

    // MARK: - Invalidators

    private func resetTransform() {
        if shouldFlipHorizontally {
            let w = layer?.bounds.size.width ?? 0
            let affine = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0)
            layer?.transform = CATransform3DMakeAffineTransform(affine)
        } else {
            layer?.transform = CATransform3DIdentity
        }
    }

    private func invalidateFrame() {
        var effectiveScale = scale
        if scale == 0.0 || image == nil {
            effectiveScale = window?.backingScaleFactor ?? 1.0
        }
        if effectiveScale == 0.0 { effectiveScale = 1.0 }

        if scale != 0.0, image != nil {
            effectiveScale = scale
        } else if scale == 0.0, image != nil {
            effectiveScale = image?.recommendedLayerContentsScale(window?.backingScaleFactor ?? 1.0) ?? 1.0
        } else if let placeholder = placeholderImage {
            effectiveScale = placeholder.recommendedLayerContentsScale(window?.backingScaleFactor ?? 1.0)
        }

        layer?.contentsScale       = effectiveScale
        spriteLayer?.contentsScale = layer?.contentsScale ?? 1.0

        if let img = image {
            let fc = max(frameCount, 1)
            let effectiveSize = CGSize(width: img.size.width, height: img.size.height / CGFloat(fc))
            let layerWidth  = layer?.frame.size.width  ?? 0
            let layerHeight = layer?.frame.size.height ?? 0
            let effectiveRect = CGRect(
                x: layerWidth  / 2.0 - effectiveSize.width  / 2.0,
                y: layerHeight / 2.0 + effectiveSize.height / 2.0,
                width: effectiveSize.width,
                height: effectiveSize.height
            ).integral
            hotSpotLayer?.position = CGPoint(
                x: effectiveRect.minX + hotSpot.x,
                y: effectiveRect.minY - hotSpot.y)
            hotSpotLayer?.opacity = 1.0
        } else {
            hotSpotLayer?.opacity = 0.0
        }

        resetTransform()
    }

    private func invalidateAnimation() {
        spriteLayer?.removeAllAnimations()

        let none = frameCount == 1 || !shouldAnimate
        let fc   = (none || image == nil) ? 0 : frameCount
        spriteLayer?.frameCount = UInt(fc)

        let anim              = CABasicAnimation(keyPath: "sampleIndex")
        anim.fromValue        = fc + 1
        anim.toValue          = 1
        anim.byValue          = -1
        anim.duration         = frameDuration * Double(fc)
        anim.repeatCount      = none ? 0 : .greatestFiniteMagnitude
        anim.autoreverses     = false
        anim.isRemovedOnCompletion = none
        anim.timingFunction   = CAMediaTimingFunction(name: .linear)
        spriteLayer?.add(anim, forKey: "sampleIndex")
    }

    // MARK: - CALayerDelegate (action)

    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return NSNull()
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) { }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        guard shouldAllowDragging else { return [] }
        if context == .withinApplication { return .copy }
        return .every
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        guard let win = window else { return }
        if !NSPointInRect(screenPoint, win.frame) {
            if NSEvent.modifierFlags.contains(.option) {
                dragAnimationEnded(self)
            } else if let del = delegate {
                NSShowAnimationEffect(.poof, screenPoint, .zero, self,
                                      #selector(dragAnimationEnded(_:)), nil)
                del.imageView(self, didDragOutImage: image ?? NSImage())
            }
        }
    }

    @objc private func dragAnimationEnded(_ sender: Any?) {
        NSCursor.arrow.set()
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard let win = window else { return }
        if !NSPointInRect(screenPoint, win.frame) {
            if NSEvent.modifierFlags.contains(.option) {
                NSCursor.dragCopy.set()
            } else {
                NSCursor.disappearingItem.set()
            }
        } else if NSCursor.current == NSCursor.disappearingItem {
            dragAnimationEnded(self)
        }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { return false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return shouldAllowDragging }

    override func mouseDown(with event: NSEvent) {
        guard let img = image, shouldAllowDragging else { return }

        let pbItem = NSPasteboardItem()
        pbItem.setDataProvider(self, forTypes: [
            .png, .tiff,
            NSPasteboard.PasteboardType("public.image"),
            NSPasteboard.PasteboardType(kPasteboardTypeFileURLPromise as String),
        ])

        let dragItem = NSDraggingItem(pasteboardWriter: pbItem)

        weak var weakSelf = self
        let previewImage = NSImage(size: frame.size, flipped: false) { _ in
            guard let s = weakSelf else { return false }
            let opacity = s.hotSpotLayer?.opacity ?? 1.0
            s.hotSpotLayer?.opacity = 0.0
            s.displayRectIgnoringOpacity(s.bounds, in: NSGraphicsContext.current!)
            s.hotSpotLayer?.opacity = opacity
            return true
        }

        dragItem.setDraggingFrame(bounds, contents: previewImage)
        _ = img // suppress unused warning
        let session = beginDraggingSession(with: [dragItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false
        session.draggingFormation = .none
    }

    // MARK: - NSPasteboardItemDataProvider

    func pasteboard(_ sender: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        guard let sender = sender else { return }
        if type == .tiff {
            sender.setData(image?.tiffRepresentation, forType: .tiff)
        } else if type == NSPasteboard.PasteboardType("public.image") {
            if let img = image { sender.writeObjects([img]) }
        } else if type == NSPasteboard.PasteboardType(kPasteboardTypeFileURLPromise as String),
                  NSEvent.modifierFlags.contains(.option) {
            guard let locStr = item.string(forType: NSPasteboard.PasteboardType("com.apple.pastelocation")),
                  let baseURL = URL(string: locStr) else { return }
            let fileName = "Mousecape Image (\(Date().timeIntervalSince1970)).tiff"
            let url = baseURL.appendingPathComponent(fileName)
            if let rep = image?.representations.first as? NSBitmapImageRep {
                rep.tiffRepresentation(using: .lzw, factor: 1.0)?.write(toFile: url.path, atomically: false)
            }
        }
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingSource as? MMAnimatingImageView !== self,
              let del = delegate,
              del.conforms(to: MMAnimatingImageViewDelegate.self),
              NSImage.canInit(with: sender.draggingPasteboard),
              shouldAllowDragging else { return [] }
        return del.imageView(self, draggingEntered: sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let del = delegate, shouldAllowDragging else { return false }
        return del.imageView(self, shouldPrepareForDragOperation: sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let del = delegate,
              del.imageView(self, shouldPerformDragOperation: sender) else { return false }

        let objects = sender.draggingPasteboard.readObjects(
            forClasses: [NSImage.self, NSURL.self], options: nil) ?? []
        var accepted: [NSImageRep] = []
        for obj in objects {
            if let img = obj as? NSImage, let rep = img.representations.first {
                accepted.append(rep)
            } else if let url = obj as? URL, let rep = NSImageRep(contentsOf: url) {
                accepted.append(rep)
            }
        }
        guard !accepted.isEmpty else { return false }
        del.imageView(self, didAcceptDroppedImages: accepted)
        return true
    }
}
