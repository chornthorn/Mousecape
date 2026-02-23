// CapeRowView.swift
// Mousecape
//
// SwiftUI row view for a single MCCursorLibrary entry in the library list.

import SwiftUI

struct CapeRowView: View {

    @ObservedObject var cape: ObservableCape
    let isApplied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(cape.name)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
                Text("by")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(cape.author)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                if isApplied {
                    Image("applied")
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                if cape.isHiDPI {
                    Image("HDTemplate")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 30, height: 18)
                }
            }

            // Horizontal cursor thumbnail strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    let sortedCursors = cape.sortedCursors
                    ForEach(sortedCursors, id: \.identifier) { cursor in
                        CursorThumbnailView(cursor: cursor, size: 40)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 44)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

// MARK: - ObservableCape

/// A lightweight KVO-observable wrapper around MCCursorLibrary for use with SwiftUI @ObservedObject.
final class ObservableCape: NSObject, ObservableObject {

    let library: MCCursorLibrary

    @Published var name: String
    @Published var author: String
    @Published var isHiDPI: Bool
    @Published var sortedCursors: [MCCursor] = []

    private var observers: [NSKeyValueObservation] = []

    init(_ library: MCCursorLibrary) {
        self.library = library
        self.name = library.name
        self.author = library.author
        self.isHiDPI = library.isHiDPI
        super.init()

        self.sortedCursors = Self.sorted(library.cursors)

        let nameObs = library.observe(\.name, options: [.new]) { [weak self] lib, _ in
            DispatchQueue.main.async { self?.name = lib.name }
        }
        let authorObs = library.observe(\.author, options: [.new]) { [weak self] lib, _ in
            DispatchQueue.main.async { self?.author = lib.author }
        }
        let hiDPIObs = library.observe(\.isHiDPI, options: [.new]) { [weak self] lib, _ in
            DispatchQueue.main.async { self?.isHiDPI = lib.isHiDPI }
        }
        observers = [nameObs, authorObs, hiDPIObs]

        // Observe cursor set changes via traditional KVO
        library.addObserver(self, forKeyPath: "cursors",
                            options: [.initial, .new, .old],
                            context: nil)
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
                self.sortedCursors = Self.sorted(self.library.cursors)
            }
        }
    }

    private static func sorted(_ set: NSSet) -> [MCCursor] {
        return (set.allObjects as? [MCCursor] ?? [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
