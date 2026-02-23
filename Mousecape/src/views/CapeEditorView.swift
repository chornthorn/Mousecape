// CapeEditorView.swift
// Mousecape
//
// SwiftUI form for editing MCCursorLibrary properties.
// Replaces MCEditCapeController + the cape portion of Edit.xib.

import SwiftUI

struct CapeEditorView: View {

    @ObservedObject var observable: ObservableCursorLibrary

    var body: some View {
        Form {
            Section {
                LabeledContent(NSLocalizedString("Name", comment: "Cape property label")) {
                    TextField("", text: $observable.name)
                        .labelsHidden()
                }

                LabeledContent(NSLocalizedString("Author", comment: "Cape property label")) {
                    TextField("", text: $observable.author)
                        .labelsHidden()
                }

                LabeledContent(NSLocalizedString("Identifier", comment: "Cape property label")) {
                    TextField("", text: $observable.identifier)
                        .labelsHidden()
                        .font(.system(.body, design: .monospaced))
                }

                LabeledContent(NSLocalizedString("Version", comment: "Cape property label")) {
                    TextField("", value: $observable.version, format: .number)
                        .labelsHidden()
                }

                Toggle(NSLocalizedString("HiDPI", comment: "HiDPI toggle"),
                       isOn: $observable.isHiDPI)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - ObservableCursorLibrary

/// Two-way binding wrapper around MCCursorLibrary properties for SwiftUI.
final class ObservableCursorLibrary: NSObject, ObservableObject {

    let library: MCCursorLibrary
    private var kvoObservers: [NSKeyValueObservation] = []

    @Published var name: String {
        didSet { if library.name != name { library.name = name } }
    }
    @Published var author: String {
        didSet { if library.author != author { library.author = author } }
    }
    @Published var identifier: String {
        didSet { if library.identifier != identifier { library.identifier = identifier } }
    }
    @Published var version: Double {
        didSet {
            let num = NSNumber(value: version)
            if library.version != num { library.version = num }
        }
    }
    @Published var isHiDPI: Bool {
        didSet { if library.isHiDPI != isHiDPI { library.isHiDPI = isHiDPI } }
    }
    @Published var cursors: [MCCursor] = []

    init(_ library: MCCursorLibrary) {
        self.library    = library
        self.name       = library.name
        self.author     = library.author
        self.identifier = library.identifier
        self.version    = library.version.doubleValue
        self.isHiDPI    = library.isHiDPI
        super.init()

        self.cursors = Self.sortedCursors(library)

        kvoObservers = [
            library.observe(\.name, options: [.new]) { [weak self] lib, _ in
                DispatchQueue.main.async { if self?.name != lib.name { self?.name = lib.name } }
            },
            library.observe(\.author, options: [.new]) { [weak self] lib, _ in
                DispatchQueue.main.async { if self?.author != lib.author { self?.author = lib.author } }
            },
            library.observe(\.identifier, options: [.new]) { [weak self] lib, _ in
                DispatchQueue.main.async {
                    if self?.identifier != lib.identifier { self?.identifier = lib.identifier }
                }
            },
            library.observe(\.isHiDPI, options: [.new]) { [weak self] lib, _ in
                DispatchQueue.main.async {
                    if self?.isHiDPI != lib.isHiDPI { self?.isHiDPI = lib.isHiDPI }
                }
            },
        ]

        library.addObserver(self, forKeyPath: "cursors",
                            options: [.initial, .new, .old], context: nil)
    }

    deinit {
        library.removeObserver(self, forKeyPath: "cursors")
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == "cursors" {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cursors = Self.sortedCursors(self.library)
            }
        }
    }

    static func sortedCursors(_ library: MCCursorLibrary) -> [MCCursor] {
        return (library.cursors.allObjects as? [MCCursor] ?? [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
