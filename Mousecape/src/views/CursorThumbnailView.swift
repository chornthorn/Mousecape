// CursorThumbnailView.swift
// Mousecape
//
// NSViewRepresentable wrapping MMAnimatingImageView for use in SwiftUI.

import SwiftUI
import AppKit

/// A SwiftUI view that hosts an `MMAnimatingImageView` for displaying animated cursor frames.
struct CursorThumbnailView: NSViewRepresentable {

    let cursor: MCCursor
    var size: CGFloat = 40

    func makeNSView(context: Context) -> MMAnimatingImageView {
        let view = MMAnimatingImageView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.shouldAllowDragging = false
        view.shouldAnimate = true
        return view
    }

    func updateNSView(_ view: MMAnimatingImageView, context: Context) {
        view.image = cursor.imageWithAllReps()
        view.frameCount = cursor.frameCount
        view.frameDuration = cursor.frameDuration
        let flipped = UserDefaults.standard.integer(forKey: MCPreferencesHandednessKey) == 1
        view.shouldFlipHorizontally = flipped
    }
}

/// A SwiftUI view that hosts an `MMAnimatingImageView` as a drag-and-drop representation editor.
struct RepresentationImageView: NSViewRepresentable {

    let cursor: MCCursor
    let scale: MCCursorScale
    var viewSize: CGFloat = 64

    /// Callback when new images are dropped.
    var onImagesDropped: (([NSImageRep], Bool) -> Void)?
    /// Callback when image is dragged out.
    var onImageDraggedOut: (() -> Void)?

    func makeNSView(context: Context) -> MMAnimatingImageView {
        let view = MMAnimatingImageView(frame: NSRect(x: 0, y: 0, width: viewSize, height: viewSize))
        view.shouldAllowDragging = true
        view.shouldAnimate = true
        view.placeholderImage = NSImage(named: "dropzone")
        view.scale = CGFloat(scale.rawValue) / 100.0
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ view: MMAnimatingImageView, context: Context) {
        let rep = cursor.representationForScale(scale)
        if let rep = rep {
            let img = NSImage(size: NSSize(
                width: Double(rep.pixelsWide) / (CGFloat(scale.rawValue) / 100.0),
                height: Double(rep.pixelsHigh) / (CGFloat(scale.rawValue) / 100.0)))
            img.addRepresentation(rep)
            view.image = img
        } else {
            view.image = nil
        }
        view.frameCount = cursor.frameCount
        view.frameDuration = cursor.frameDuration
        context.coordinator.owner = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(owner: self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MMAnimatingImageViewDelegate {
        var owner: RepresentationImageView

        init(owner: RepresentationImageView) {
            self.owner = owner
        }

        func imageView(_ imageView: MMAnimatingImageView,
                       draggingEntered drop: NSDraggingInfo) -> NSDragOperation {
            return .copy
        }

        func imageView(_ imageView: MMAnimatingImageView,
                       shouldPrepareForDragOperation drop: NSDraggingInfo) -> Bool { return true }

        func imageView(_ imageView: MMAnimatingImageView,
                       shouldPerformDragOperation drop: NSDraggingInfo) -> Bool { return true }

        func imageView(_ imageView: MMAnimatingImageView, didAcceptDroppedImages images: [NSImageRep]) {
            let isOption = NSEvent.modifierFlags == .option
            owner.onImagesDropped?(images, isOption)
        }

        func imageView(_ imageView: MMAnimatingImageView, didDragOutImage image: NSImage) {
            owner.onImageDraggedOut?()
        }
    }
}
