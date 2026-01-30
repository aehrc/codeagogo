import SwiftUI
import Carbon.HIToolbox

struct SettingsView: View {
    @ObservedObject private var hk = HotKeySettings.shared
    @ObservedObject private var searchHk = SearchHotKeySettings.shared
    @ObservedObject private var searchSettings = SearchSettings.shared
    @ObservedObject private var replaceHk = ReplaceHotKeySettings.shared
    @ObservedObject private var replaceSettings = ReplaceSettings.shared
    @ObservedObject private var eclFormatHk = ECLFormatHotKeySettings.shared

    // Logging setting persisted in UserDefaults
    @AppStorage(AppLog.debugKey) private var debugLoggingEnabled: Bool = false

    private let lookupKeys: [(String, UInt32)] = [
        ("L", UInt32(kVK_ANSI_L)),
        ("K", UInt32(kVK_ANSI_K)),
        ("Y", UInt32(kVK_ANSI_Y)),
        ("U", UInt32(kVK_ANSI_U))
    ]

    private let searchKeys: [(String, UInt32)] = [
        ("S", UInt32(kVK_ANSI_S)),
        ("F", UInt32(kVK_ANSI_F)),
        ("K", UInt32(kVK_ANSI_K)),
        ("Y", UInt32(kVK_ANSI_Y))
    ]

    private let replaceKeys: [(String, UInt32)] = [
        ("R", UInt32(kVK_ANSI_R)),
        ("Y", UInt32(kVK_ANSI_Y)),
        ("K", UInt32(kVK_ANSI_K)),
        ("U", UInt32(kVK_ANSI_U))
    ]

    private let eclFormatKeys: [(String, UInt32)] = [
        ("E", UInt32(kVK_ANSI_E)),
        ("F", UInt32(kVK_ANSI_F)),
        ("P", UInt32(kVK_ANSI_P)),
        ("M", UInt32(kVK_ANSI_M))
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("SNOMED Lookup").font(.title2)

                GroupBox("Lookup Hotkey") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Key")
                            Picker("", selection: $hk.keyCode) {
                                ForEach(lookupKeys, id: \.1) { item in
                                    Text(item.0).tag(item.1)
                                }
                            }
                            .frame(width: 120)
                            .accessibilityIdentifier("settings.lookupHotkeyKey")
                            .accessibilityLabel("Lookup hotkey letter")
                            .accessibilityHint("Select the letter key for the lookup hotkey")
                        }

                        modifierToggles(for: .lookup)

                        Text("Looks up the selected SNOMED CT concept ID.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding(.top, 4)
                }

                GroupBox("Search Hotkey") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Key")
                            Picker("", selection: $searchHk.keyCode) {
                                ForEach(searchKeys, id: \.1) { item in
                                    Text(item.0).tag(item.1)
                                }
                            }
                            .frame(width: 120)
                            .accessibilityIdentifier("settings.searchHotkeyKey")
                            .accessibilityLabel("Search hotkey letter")
                            .accessibilityHint("Select the letter key for the search hotkey")
                        }

                        modifierToggles(for: .search)

                        Text("Opens a panel to search and insert SNOMED CT concepts.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding(.top, 4)
                }

                GroupBox("Replace Hotkey") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Key")
                            Picker("", selection: $replaceHk.keyCode) {
                                ForEach(replaceKeys, id: \.1) { item in
                                    Text(item.0).tag(item.1)
                                }
                            }
                            .frame(width: 120)
                            .accessibilityIdentifier("settings.replaceHotkeyKey")
                            .accessibilityLabel("Replace hotkey letter")
                            .accessibilityHint("Select the letter key for the replace hotkey")
                        }

                        modifierToggles(for: .replace)

                        Picker("Term format:", selection: $replaceSettings.termFormat) {
                            ForEach(ReplaceTermFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .frame(width: 280)
                        .accessibilityIdentifier("settings.replaceTermFormat")
                        .accessibilityLabel("Replace term format")
                        .accessibilityHint("Select whether to use FSN or PT in the replacement")

                        Text("Replaces selected concept ID with ID | term |")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding(.top, 4)
                }

                GroupBox("ECL Format Hotkey") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Key")
                            Picker("", selection: $eclFormatHk.keyCode) {
                                ForEach(eclFormatKeys, id: \.1) { item in
                                    Text(item.0).tag(item.1)
                                }
                            }
                            .frame(width: 120)
                            .accessibilityIdentifier("settings.eclFormatHotkeyKey")
                            .accessibilityLabel("ECL format hotkey letter")
                            .accessibilityHint("Select the letter key for the ECL format hotkey")
                        }

                        modifierToggles(for: .eclFormat)

                        Text("Formats selected ECL expression for readability.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding(.top, 4)
                }

                GroupBox("Insert Format") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Default format:", selection: $searchSettings.selectedFormat) {
                            ForEach(InsertFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .frame(width: 250)
                        .accessibilityIdentifier("settings.insertFormat")
                        .accessibilityLabel("Insert format")
                        .accessibilityHint("Select how concepts are formatted when inserted")

                        Text("Format used when inserting concepts from the search panel.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding(.top, 4)
                }

                Text("Accessibility permission required (System Settings → Privacy & Security → Accessibility).")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .padding(.top, 4)
            
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
                        .accessibilityIdentifier("settings.fhirBaseURL")
                        .accessibilityLabel("FHIR server base URL")
                        .accessibilityHint("Enter the base URL of the FHIR terminology server")
                    }

                    HStack(spacing: 10) {
                        Button("Save") {
                            FHIROptions.shared.save()
                        }
                        .accessibilityIdentifier("settings.saveButton")
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
                        .accessibilityIdentifier("settings.debugLogging")
                        .accessibilityHint("Enable detailed logging for troubleshooting")

                    HStack(spacing: 10) {
                        Button("Copy diagnostics to clipboard") {
                            Diagnostics.copyRecentLogsToClipboard(minutes: 15)
                        }
                        .accessibilityIdentifier("settings.diagnosticsButton")
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
        }
        .frame(width: 520, height: 780)
    }

    // MARK: - Modifier Toggles

    private enum HotKeyType {
        case lookup
        case search
        case replace
        case eclFormat

        var accessibilityPrefix: String {
            switch self {
            case .lookup: return "settings.lookup"
            case .search: return "settings.search"
            case .replace: return "settings.replace"
            case .eclFormat: return "settings.eclFormat"
            }
        }
    }

    @ViewBuilder
    private func modifierToggles(for type: HotKeyType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modifiers")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle("Control", isOn: bindingFor(.control, type: type))
                .accessibilityIdentifier("\(type.accessibilityPrefix).control")
                .accessibilityHint("Include Control key in hotkey combination")
            Toggle("Option", isOn: bindingFor(.option, type: type))
                .accessibilityIdentifier("\(type.accessibilityPrefix).option")
                .accessibilityHint("Include Option key in hotkey combination")
            Toggle("Command", isOn: bindingFor(.command, type: type))
                .accessibilityIdentifier("\(type.accessibilityPrefix).command")
                .accessibilityHint("Include Command key in hotkey combination")
            Toggle("Shift", isOn: bindingFor(.shift, type: type))
                .accessibilityIdentifier("\(type.accessibilityPrefix).shift")
                .accessibilityHint("Include Shift key in hotkey combination")
        }
    }

    private func bindingFor(_ flag: NSEvent.ModifierFlags, type: HotKeyType) -> Binding<Bool> {
        Binding(
            get: {
                let raw = HotKeySettings.carbonModifiers(from: [flag])
                switch type {
                case .lookup:
                    return (hk.modifiersRaw & raw) != 0
                case .search:
                    return (searchHk.modifiersRaw & raw) != 0
                case .replace:
                    return (replaceHk.modifiersRaw & raw) != 0
                case .eclFormat:
                    return (eclFormatHk.modifiersRaw & raw) != 0
                }
            },
            set: { on in
                let raw = HotKeySettings.carbonModifiers(from: [flag])
                switch type {
                case .lookup:
                    if on {
                        hk.modifiersRaw |= raw
                    } else {
                        hk.modifiersRaw &= ~raw
                    }
                case .search:
                    if on {
                        searchHk.modifiersRaw |= raw
                    } else {
                        searchHk.modifiersRaw &= ~raw
                    }
                case .replace:
                    if on {
                        replaceHk.modifiersRaw |= raw
                    } else {
                        replaceHk.modifiersRaw &= ~raw
                    }
                case .eclFormat:
                    if on {
                        eclFormatHk.modifiersRaw |= raw
                    } else {
                        eclFormatHk.modifiersRaw &= ~raw
                    }
                }
            }
        )
    }
}

