import SwiftUI
import Carbon.HIToolbox

struct SettingsView: View {
    @ObservedObject private var hk = HotKeySettings.shared

    // Logging setting persisted in UserDefaults
    @AppStorage(AppLog.debugKey) private var debugLoggingEnabled: Bool = false

    private let keys: [(String, UInt32)] = [
        ("L", UInt32(kVK_ANSI_L)),
        ("K", UInt32(kVK_ANSI_K)),
        ("Y", UInt32(kVK_ANSI_Y)),
        ("U", UInt32(kVK_ANSI_U))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SNOMED Lookup").font(.title2)

            GroupBox("Hotkey") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Key")
                        Picker("", selection: $hk.keyCode) {
                            ForEach(keys, id: \.1) { item in
                                Text(item.0).tag(item.1)
                            }
                        }
                        .frame(width: 120)
                        .accessibilityLabel("Hotkey letter")
                        .accessibilityHint("Select the letter key for the hotkey")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Modifiers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Toggle("Control", isOn: bindingFor(.control))
                            .accessibilityHint("Include Control key in hotkey combination")
                        Toggle("Option", isOn: bindingFor(.option))
                            .accessibilityHint("Include Option key in hotkey combination")
                        Toggle("Command", isOn: bindingFor(.command))
                            .accessibilityHint("Include Command key in hotkey combination")
                        Toggle("Shift", isOn: bindingFor(.shift))
                            .accessibilityHint("Include Shift key in hotkey combination")
                    }

                    Text("Reading selection requires Accessibility permission (System Settings → Privacy & Security → Accessibility).")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .padding(.top, 4)
            }
            
            GroupBox("FHIR Endpoint") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        Text("Base URL")
                        TextField("https://tx.ontoserver.csiro.au/fhir", text: Binding(
                            get: { FHIROptions.shared.baseURLString },
                            set: { FHIROptions.shared.baseURLString = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disableAutocorrection(true)
                        .accessibilityLabel("FHIR server base URL")
                        .accessibilityHint("Enter the base URL of the FHIR terminology server")
                    }

                    HStack(spacing: 10) {
                        Button("Save") {
                            FHIROptions.shared.save()
                        }
                        .accessibilityHint("Save the FHIR endpoint configuration")
                        Text("Requests will use this FHIR server. Invalid URLs fall back to the default.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Logging") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable debug logging", isOn: $debugLoggingEnabled)
                        .accessibilityHint("Enable detailed logging for troubleshooting")

                    HStack(spacing: 10) {
                        Button("Copy diagnostics to clipboard") {
                            Diagnostics.copyRecentLogsToClipboard(minutes: 15)
                        }
                        .accessibilityHint("Copies recent log entries to clipboard for sharing")

                        Text("Turn on debug logging, reproduce the issue, then copy diagnostics.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 520, height: 460)
    }

    private func bindingFor(_ flag: NSEvent.ModifierFlags) -> Binding<Bool> {
        Binding(
            get: {
                let raw = HotKeySettings.carbonModifiers(from: [flag])
                return (hk.modifiersRaw & raw) != 0
            },
            set: { on in
                let raw = HotKeySettings.carbonModifiers(from: [flag])
                if on {
                    hk.modifiersRaw |= raw
                } else {
                    hk.modifiersRaw &= ~raw
                }
            }
        )
    }
}

