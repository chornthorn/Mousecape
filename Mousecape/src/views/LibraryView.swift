// LibraryView.swift
// Mousecape
//
// SwiftUI library window — replaces Library.xib + MCLibraryWindowController + MCLibraryViewController.

import SwiftUI
import AppKit

struct LibraryView: View {

    @EnvironmentObject private var store: LibraryStore
    @Environment(\.openWindow) private var openWindow

    @State private var selectedCapeID: ObjectIdentifier?
    @State private var capeObservables: [ObjectIdentifier: ObservableCape] = [:]

    // MARK: - Computed

    private var selectedCape: MCCursorLibrary? {
        guard let id = selectedCapeID else { return nil }
        return store.capes.first { ObjectIdentifier($0) == id }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main list
            List(store.capes, id: \.self, selection: $selectedCapeID) { cape in
                let id = ObjectIdentifier(cape)
                capeRowView(cape: cape, id: id)
                    .tag(id)
            }
            .listStyle(.plain)
            .onTapGesture(count: 2) {
                handleDoubleClick()
            }

            // Dump progress overlay
            if store.isDumping {
                dumpProgressOverlay
            }
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(appliedAccessoryText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .onReceive(store.$capes) { newCapes in
            let ids = Set(newCapes.map { ObjectIdentifier($0) })
            capeObservables = capeObservables.filter { ids.contains($0.key) }
        }
    }

    // MARK: - Row builder

    @ViewBuilder
    private func capeRowView(cape: MCCursorLibrary, id: ObjectIdentifier) -> some View {
        let obs: ObservableCape = {
            if let existing = capeObservables[id] { return existing }
            let newObs = ObservableCape(cape)
            DispatchQueue.main.async { capeObservables[id] = newObs }
            return newObs
        }()
        CapeRowView(cape: obs, isApplied: store.appliedCape === cape)
            .contextMenu { capeContextMenu(for: cape) }
    }

    // MARK: - Applied accessory text

    private var appliedAccessoryText: String {
        let prefix = NSLocalizedString("Applied Cape: ", comment: "Accessory label for applied cape")
        let none   = NSLocalizedString("None", comment: "No cape applied placeholder")
        return prefix + (store.appliedCape?.name ?? none)
    }

    // MARK: - Dump progress overlay

    private var dumpProgressOverlay: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(store.dumpProgress.current),
                         total: max(1, Double(store.dumpProgress.total)))
                .frame(width: 300)
            Text("\(store.dumpProgress.current) "
                 + NSLocalizedString("of", comment: "progress separator")
                 + " \(store.dumpProgress.total)")
                .font(.caption)
        }
        .padding(20)
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    // MARK: - Double-click

    private func handleDoubleClick() {
        guard let cape = selectedCape else { return }
        let doubleAction = UserDefaults.standard.integer(forKey: MCPreferencesDoubleActionKey)
        if doubleAction == 0 {
            store.applyCape(cape)
        } else {
            editCape(cape)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func capeContextMenu(for cape: MCCursorLibrary) -> some View {
        Button(NSLocalizedString("Apply", comment: "Context menu Apply")) {
            store.applyCape(cape)
        }
        Button(NSLocalizedString("Edit", comment: "Context menu Edit")) {
            editCape(cape)
        }
        Button(NSLocalizedString("Duplicate", comment: "Context menu Duplicate")) {
            if let copy = cape.copy() as? MCCursorLibrary {
                store.importCape(copy)
            }
        }
        Divider()
        Button(NSLocalizedString("Remove", comment: "Context menu Remove"),
               role: .destructive) {
            store.removeCape(cape)
        }
        Divider()
        Button(NSLocalizedString("Show in Finder", comment: "Context menu Show in Finder")) {
            if let url = cape.fileURL {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    // MARK: - Edit

    private func editCape(_ cape: MCCursorLibrary) {
        store.editingCape = cape
        openWindow(id: "edit")
    }
}
