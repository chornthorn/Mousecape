// NSOrderedSet+AZSortedInsert.swift
// Mousecape
//
// Swift replacement for NSOrderedSet+AZSortedInsert.h / .m

import Foundation

extension NSOrderedSet {

    /// Binary-search index at which to insert `anObject` while keeping the set sorted.
    @objc func indexForInsertingObject(
        _ anObject: Any,
        sortedUsingComparator comparator: (Any, Any) -> ComparisonResult
    ) -> Int {
        var lo = 0
        var hi = count
        while lo < hi {
            let mid = (lo + hi) / 2
            if comparator(anObject, object(at: mid)) == .orderedDescending {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo
    }

    @objc func indexForInsertingObject(
        _ anObject: Any,
        sortedUsing aSelector: Selector
    ) -> Int {
        return indexForInsertingObject(anObject) { a, b in
            let result = (a as AnyObject).perform(aSelector, with: b)
            return ComparisonResult(rawValue: Int(bitPattern: result?.toOpaque())) ?? .orderedSame
        }
    }

    @objc func indexForInsertingObject(
        _ anObject: Any,
        sortedUsing descriptors: [NSSortDescriptor]
    ) -> Int {
        return indexForInsertingObject(anObject) { a, b in
            var result: ComparisonResult = .orderedSame
            for descriptor in descriptors {
                result = descriptor.compare(a, to: b)
                if result != .orderedSame { break }
            }
            return result
        }
    }
}

extension NSMutableOrderedSet {

    @objc func insertObject(
        _ anObject: Any,
        sortedUsingComparator comparator: (Any, Any) -> ComparisonResult
    ) {
        let index = indexForInsertingObject(anObject, sortedUsingComparator: comparator)
        insert(anObject, at: index)
    }

    @objc func insertObject(_ anObject: Any, sortedUsing aSelector: Selector) {
        let index = indexForInsertingObject(anObject, sortedUsing: aSelector)
        insert(anObject, at: index)
    }

    @objc func insertObject(_ anObject: Any, sortedUsing descriptors: [NSSortDescriptor]) {
        let index = indexForInsertingObject(anObject, sortedUsing: descriptors)
        insert(anObject, at: index)
    }
}
