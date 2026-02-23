// MCCapePreviewItem.swift
// Mousecape
//
// Swift replacement for MCCapePreviewItem.h / MCCapePreviewItem.m

import AppKit

@objc(MCCapePreviewItem) class MCCapePreviewItem: NSCollectionViewItem {

    @IBOutlet weak var animatingImageView: MMAnimatingImageView?

    override init(nibName: NSNib.Name?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        view = container

        let iv = MMAnimatingImageView(frame: container.bounds)
        iv.shouldAllowDragging = false
        animatingImageView = iv
        container.addSubview(iv)

        iv.bind(NSBindingName("image"),
                to: self, withKeyPath: "representedObject.imageWithAllReps",
                options: nil)
        iv.bind(NSBindingName("frameCount"),
                to: self, withKeyPath: "representedObject.frameCount",
                options: nil)
        iv.bind(NSBindingName("frameDuration"),
                to: self, withKeyPath: "representedObject.frameDuration",
                options: nil)
        iv.bind(NSBindingName("shouldFlipHorizontally"),
                to: NSUserDefaults.standard,
                withKeyPath: MCPreferencesHandednessKey,
                options: nil)
    }

    deinit {
        animatingImageView?.unbind(NSBindingName("shouldFlipHorizontally"))
        animatingImageView?.unbind(NSBindingName("image"))
        animatingImageView?.unbind(NSBindingName("frameCount"))
        animatingImageView?.unbind(NSBindingName("frameDuration"))
    }
}
