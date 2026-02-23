// MCEditCapeController.swift
// Mousecape
//
// Swift replacement for MCEditCapeController.h / .m

import AppKit

@objc(MCEditCapeController) class MCEditCapeController: NSViewController {

    @objc var cursorLibrary: MCCursorLibrary?

    override init(nibName: NSNib.Name?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func validateValue(
        _ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>,
        forKeyPath inKeyPath: String
    ) throws {
        if inKeyPath == "cursorLibrary.identifier" {
            let proposed = ioValue.pointee as? String ?? ""
            let valid    = cursorLibrary?.library?.capes(withIdentifier: proposed).count == 0
            if !valid {
                throw NSError(
                    domain: MCErrorDomain,
                    code: MCErrorCode.multipleCursorIdentifiers.rawValue,
                    userInfo: [
                        NSLocalizedDescriptionKey: NSLocalizedString(
                            "A cape with this identifier already exists",
                            comment: "Duplicate cape identifier error"),
                    ])
            }
        }
    }
}
