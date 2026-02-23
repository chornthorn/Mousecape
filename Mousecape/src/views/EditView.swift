// EditView.swift
// Mousecape
//
// SwiftUI edit window with NavigationSplitView — replaces Edit.xib +
// MCEditWindowController + MCEditListController + MCEditDetailController + MCEditCapeController.

import SwiftUI
import AppKit

struct EditView: View {

    @EnvironmentObject private var store: LibraryStore

    /// Local reference to the cape being edited; resolves from store.editingCape.
    @State private var libraryObs: ObservableCursorLibrary?
    @State private var selectedCursorID: String?   // cursor.identifier or "__cape__"

    private let capeListID = "__cape__"

    // MARK: - Body

    var body: some View {
        Group {
            if let obs = libraryObs {
                NavigationSplitView {
                    sidebarList(obs: obs)
                } detail: {
                    detailView(obs: obs)
                }
                .navigationSplitViewStyle(.balanced)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(NSLocalizedString("Save", comment: "Save button")) {
                            if let error = obs.library.save() {
                                NSApp.presentError(error)
                            }
                        }
                        Button(NSLocalizedString("Revert", comment: "Revert button")) {
                            obs.library.revertToSaved()
                            libraryObs = ObservableCursorLibrary(obs.library)
                        }
                        Button(NSLocalizedString("Apply Cape", comment: "Apply button")) {
                            store.applyCape(obs.library)
                        }
                    }
                }
            } else {
                Text(NSLocalizedString("No cape selected", comment: "Edit window placeholder"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.secondary)
            }
        }
        .onReceive(store.$editingCape) { cape in
            if let cape = cape {
                libraryObs = ObservableCursorLibrary(cape)
                selectedCursorID = capeListID
            } else {
                libraryObs = nil
                selectedCursorID = nil
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private func sidebarList(obs: ObservableCursorLibrary) -> some View {
        List(selection: $selectedCursorID) {
            // Library header row
            Text(obs.name)
                .font(.system(size: 13, weight: .bold))
                .tag(capeListID)
                .listRowBackground(Color.clear)

            Divider()

            // Cursor rows
            ForEach(obs.cursors, id: \.identifier) { cursor in
                Text(cursor.name)
                    .tag(cursor.identifier)
                    .contextMenu {
                        Button(NSLocalizedString("Duplicate", comment: "Duplicate cursor")) {
                            if let copy = cursor.copy() as? MCCursor {
                                copy.identifier = Foundation.UUID().uuidString
                                obs.library.addCursor(copy)
                            }
                        }
                        Button(NSLocalizedString("Remove", comment: "Remove cursor"),
                               role: .destructive) {
                            obs.library.removeCursor(cursor)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 120, maxWidth: 200)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 0) {
                Button(action: { obs.library.addCursor(MCCursor()) }) {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)

                Button(action: {
                    if let id = selectedCursorID,
                       id != capeListID,
                       let cursor = obs.cursors.first(where: { $0.identifier == id }) {
                        obs.library.removeCursor(cursor)
                        selectedCursorID = capeListID
                    }
                }) {
                    Image(systemName: "minus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .disabled(selectedCursorID == nil || selectedCursorID == capeListID)

                Spacer()
            }
            .padding(.horizontal, 4)
            .frame(height: 22)
            .background(.bar)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private func detailView(obs: ObservableCursorLibrary) -> some View {
        if selectedCursorID == nil || selectedCursorID == capeListID {
            CapeEditorView(observable: obs)
        } else if let id = selectedCursorID,
                  let cursor = obs.cursors.first(where: { $0.identifier == id }) {
            CursorEditorView(cursor: cursor)
        } else {
            Text(NSLocalizedString("Select an item", comment: "Edit detail placeholder"))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
