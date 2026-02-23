// SettingsView.swift
// Mousecape
//
// SwiftUI Settings scene — replaces MASPreferences + MCGeneralPreferencesController.

import SwiftUI

struct SettingsView: View {

    @AppStorage(MCPreferencesCursorScaleKey) private var cursorScaleDefault: Double = 1.0
    @AppStorage(MCPreferencesDoubleActionKey) private var doubleAction: Int = 1
    @AppStorage(MCPreferencesHandednessKey) private var handedness: Int = 0

    @State private var cursorScaleDisplay: Double = 1.0

    var body: some View {
        Form {
            // Handedness
            Section {
                Picker(NSLocalizedString("I am…", comment: "Handedness label"),
                       selection: $handedness) {
                    Text(NSLocalizedString("right", comment: "Right-handed")).tag(0)
                    Text(NSLocalizedString("left",  comment: "Left-handed")).tag(1)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Text(NSLocalizedString("handed", comment: "Handedness suffix"))
            }

            // Double-click action
            Section {
                Picker(NSLocalizedString("Double Clicks", comment: "Double click label"),
                       selection: $doubleAction) {
                    Text(NSLocalizedString("apply", comment: "Apply action")).tag(0)
                    Text(NSLocalizedString("edit",  comment: "Edit action")).tag(1)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Text(NSLocalizedString("capes", comment: "Double click suffix"))
            }

            // Cursor scale
            Section {
                Text(NSLocalizedString("Cursor Scale", comment: "Cursor scale label"))
                HStack {
                    Slider(
                        value: $cursorScaleDisplay,
                        in: 0.5...16,
                        step: 1
                    ) {
                        EmptyView()
                    } minimumValueLabel: {
                        EmptyView()
                    } maximumValueLabel: {
                        EmptyView()
                    }
                    .onChange(of: cursorScaleDisplay) { newValue in
                        cursorScaleDefault = newValue
                        setCursorScale(Float(newValue))
                    }

                    TextField("", value: $cursorScaleDisplay, format: .number.precision(.fractionLength(2)))
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: cursorScaleDisplay) { newValue in
                            let clamped = max(0.5, min(16, newValue))
                            cursorScaleDefault = clamped
                            setCursorScale(Float(clamped))
                        }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 360)
        .onAppear {
            cursorScaleDisplay = cursorScale()
        }
    }
}
