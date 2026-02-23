// MCSpriteLayer.swift
// Mousecape
//
// Swift replacement for MCSpriteLayer.h / MCSpriteLayer.m

import QuartzCore

@objc(MCSpriteLayer) class MCSpriteLayer: CALayer {

    @objc dynamic var frameCount: UInt = 1 {
        didSet { setNeedsDisplay() }
    }

    @objc dynamic var sampleIndex: UInt = 1 {
        didSet { setNeedsDisplay() }
    }

    // MARK: - Init

    override init() {
        super.init()
        sampleIndex  = 1
        frameCount   = 1
        anchorPoint  = .zero
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? MCSpriteLayer {
            frameCount  = other.frameCount
            sampleIndex = other.sampleIndex
        }
    }

    // MARK: - CALayer overrides

    override class func needsDisplay(forKey key: String) -> Bool {
        return key == "sampleIndex" || key == "frameCount" || super.needsDisplay(forKey: key)
    }

    override class func defaultAction(forKey aKey: String) -> CAAction? {
        return NSNull()
    }

    private var currentSampleIndex: UInt {
        return (self.presentation() as? MCSpriteLayer)?.sampleIndex ?? sampleIndex
    }

    override func display() {
        if let del = delegate, del.responds(to: #selector(CALayerDelegate.display(_:))) {
            del.display?(self)
            return
        }

        let idx = currentSampleIndex
        guard idx > 0 else { return }

        let fc = frameCount > 0 ? frameCount : 1
        let sampleHeight = 1.0 / CGFloat(fc)
        contentsRect = CGRect(
            x: 0,
            y: CGFloat(idx - 1) * sampleHeight,
            width: 1.0,
            height: sampleHeight)
    }
}
