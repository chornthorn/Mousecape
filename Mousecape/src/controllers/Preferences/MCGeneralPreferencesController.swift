// MCGeneralPreferencesController.swift
// Mousecape
//
// Swift replacement for MCGeneralPreferencesController.h / .m

import AppKit

@objc(MCGeneralPreferencesController) class MCGeneralPreferencesController: NSViewController, MASPreferencesViewController {

    // MARK: - cursorScale backed by CGS

    @objc var cursorScale: Float {
        get { return MousecloakCore.cursorScale() }
        set {
            willChangeValue(forKey: "cursorScale")
            setCursorScale(newValue)
            UserDefaults.standard.set(newValue, forKey: MCPreferencesCursorScaleKey)
            didChangeValue(forKey: "cursorScale")
        }
    }

    // MARK: - Init

    init() {
        super.init(nibName: "GeneralPreferences", bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - MASPreferencesViewController

    var identifier: String { return "GeneralPreferences" }

    var toolbarItemImage: NSImage? {
        return NSImage(named: NSImage.preferencesGeneralName)
    }

    var toolbarItemLabel: String {
        return NSLocalizedString("General", comment: "Toolbar item name for the General preference pane")
    }
}
