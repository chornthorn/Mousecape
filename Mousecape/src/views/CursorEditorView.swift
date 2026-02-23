// CursorEditorView.swift
// Mousecape
//
// SwiftUI editor for a single MCCursor — replaces MCEditDetailController + the detail portion
// of Edit.xib.

import SwiftUI
import AppKit

struct CursorEditorView: View {

    let cursor: MCCursor
    @State private var selectedTypeName: String = ""
    @State private var frameCount: String = "1"
    @State private var frameDuration: String = "1.0"
    @State private var hotSpot: String = "{0, 0}"
    @State private var size: String = "{0, 0}"
    // Reload token to force image view refresh
    @State private var reloadToken: UUID = UUID()

    private let typeNames: [String] = {
        cursorNameMap.values.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Type picker
                HStack {
                    Text(NSLocalizedString("Type", comment: "Cursor type label"))
                        .frame(width: 100, alignment: .trailing)
                    Picker("", selection: $selectedTypeName) {
                        ForEach(typeNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedTypeName) { name in
                        cursor.identifier = cursorIdentifierForName(name)
                    }
                }

                // Size
                HStack {
                    Text(NSLocalizedString("Size", comment: "Cursor size label"))
                        .frame(width: 100, alignment: .trailing)
                    TextField("", text: $size)
                        .onSubmit { applySize() }
                }

                // Frame count
                HStack {
                    Text(NSLocalizedString("Frames", comment: "Frame count label"))
                        .frame(width: 100, alignment: .trailing)
                    TextField("", text: $frameCount)
                        .onSubmit { applyFrameCount() }
                }

                // Frame duration
                HStack {
                    Text(NSLocalizedString("Duration", comment: "Frame duration label"))
                        .frame(width: 100, alignment: .trailing)
                    TextField("", text: $frameDuration)
                        .onSubmit { applyFrameDuration() }
                }

                // Hot spot
                HStack {
                    Text(NSLocalizedString("Hot Spot", comment: "Cursor hot spot label"))
                        .frame(width: 100, alignment: .trailing)
                    TextField("", text: $hotSpot)
                        .onSubmit { applyHotSpot() }
                }

                // Representation image views
                HStack(spacing: 12) {
                    repImageBox(scale: .scale100,  label: "1×")
                    repImageBox(scale: .scale200,  label: "2×")
                    repImageBox(scale: .scale500,  label: "5×")
                    repImageBox(scale: .scale1000, label: "10×")
                }
                .id(reloadToken)
            }
            .padding(16)
        }
        .onAppear { loadFields() }
    }

    // MARK: - Representation image box

    @ViewBuilder
    private func repImageBox(scale: MCCursorScale, label: String) -> some View {
        VStack(spacing: 4) {
            RepresentationImageView(
                cursor: cursor,
                scale: scale,
                viewSize: 64,
                onImagesDropped: { images, isOption in
                    handleDrop(images: images, isOption: isOption, scale: scale)
                },
                onImageDraggedOut: {
                    cursor.setRepresentation(nil, forScale: scale)
                    reloadToken = UUID()
                }
            )
            .frame(width: 64, height: 64)
            .border(Color.secondary.opacity(0.3))

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Drop handling

    private func handleDrop(images: [NSImageRep], isOption: Bool, scale: MCCursorScale) {
        if isOption {
            if let composed = MCCursor.composeRepresentation(withFrames: images) {
                cursor.addFrame(composed, forScale: scale)
            }
        } else {
            cursor.setRepresentation(MCCursor.composeRepresentation(withFrames: images),
                                     forScale: scale)
            cursor.frameCount = images.count
        }
        reloadToken = UUID()
        loadFields()
    }

    // MARK: - Field loading / applying

    private func loadFields() {
        selectedTypeName = nameForCursorIdentifier(cursor.identifier)
        frameCount    = "\(cursor.frameCount)"
        frameDuration = String(format: "%.3g", cursor.frameDuration)
        hotSpot       = NSStringFromPoint(cursor.hotSpot)
        size          = NSStringFromSize(cursor.size)
    }

    private func applyFrameCount() {
        if let v = Int(frameCount) { cursor.frameCount = v }
    }

    private func applyFrameDuration() {
        if let v = Double(frameDuration) { cursor.frameDuration = CGFloat(v) }
    }

    private func applyHotSpot() {
        cursor.hotSpot = NSPointFromString(hotSpot)
    }

    private func applySize() {
        cursor.size = NSSizeFromString(size)
    }
}
