import SwiftUI
import Carbon.HIToolbox
import Combine

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
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Modifiers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Toggle("Control", isOn: bindingFor(.control))
                        Toggle("Option", isOn: bindingFor(.option))
                        Toggle("Command", isOn: bindingFor(.command))
                        Toggle("Shift", isOn: bindingFor(.shift))
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
                    }

                    HStack(spacing: 10) {
                        Button("Save") {
                            FHIROptions.shared.save()
                        }
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

                    HStack(spacing: 10) {
                        Button("Copy diagnostics to clipboard") {
                            Diagnostics.copyRecentLogsToClipboard(minutes: 15)
                        }

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
                let raw = HotKeySettings.raw(from: [flag])
                return (hk.modifiersRaw & raw) != 0
            },
            set: { on in
                let raw = HotKeySettings.raw(from: [flag])
                if on {
                    hk.modifiersRaw |= raw
                } else {
                    hk.modifiersRaw &= ~raw
                }
            }
        )
    }
}

