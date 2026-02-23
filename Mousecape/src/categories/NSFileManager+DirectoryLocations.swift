// NSFileManager+DirectoryLocations.swift
// Mousecape
//
// Swift replacement for NSFileManager+DirectoryLocations.h / .m

import Foundation

extension FileManager {

    @objc func findOrCreateDirectory(
        _ searchPathDirectory: FileManager.SearchPathDirectory,
        inDomain domainMask: FileManager.SearchPathDomainMask,
        appendPathComponent appendComponent: String?,
        error errorOut: NSErrorPointer
    ) -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(searchPathDirectory, domainMask, true)
        guard let firstPath = paths.first else {
            errorOut?.pointee = NSError(
                domain: "DirectoryLocationDomain",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No path found for directory in domain."])
            return nil
        }

        var resolved = firstPath
        if let component = appendComponent {
            resolved = (resolved as NSString).appendingPathComponent(component)
        }

        do {
            try createDirectory(atPath: resolved, withIntermediateDirectories: true, attributes: nil)
            errorOut?.pointee = nil
            return resolved
        } catch {
            errorOut?.pointee = error as NSError
            return nil
        }
    }

    @objc var applicationSupportDirectory: String? {
        guard let executableName = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String else {
            return nil
        }
        var error: NSError?
        let result = findOrCreateDirectory(
            .applicationSupportDirectory,
            inDomain: .userDomainMask,
            appendPathComponent: executableName,
            error: &error)
        if result == nil {
            print("Unable to find or create application support directory: " +
                  (error?.localizedDescription ?? "unknown error"))
        }
        return result
    }
}
