// MCGeneralPreferencesController.swift
// Mousecape
//
// Legacy preferences controller — superseded by SettingsView.swift (SwiftUI).
// Kept for reference; no longer used as the active preferences UI.

import AppKit

@objc(MCGeneralPreferencesController) class MCGeneralPreferencesController: NSViewController {

    // MARK: - cursorScale backed by CGS

    @objc var cursorScale: Float {
        get { return Mousecape.cursorScale() }
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
}
