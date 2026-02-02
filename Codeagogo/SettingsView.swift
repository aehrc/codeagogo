import SwiftUI

struct SettingsView: View {
    @ObservedObject private var hk = HotKeySettings.shared
    @ObservedObject private var searchHk = SearchHotKeySettings.shared
    @ObservedObject private var searchSettings = SearchSettings.shared
    @ObservedObject private var replaceHk = ReplaceHotKeySettings.shared
    @ObservedObject private var replaceSettings = ReplaceSettings.shared
    @ObservedObject private var eclFormatHk = ECLFormatHotKeySettings.shared
    @ObservedObject private var codeSystemSettings = CodeSystemSettings.shared

    // Logging setting persisted in UserDefaults
    @AppStorage(AppLog.debugKey) private var debugLoggingEnabled: Bool = false

    // State for available code systems from server
    @State private var availableCodeSystems: [AvailableCodeSystem] = []
    @State private var selectedAvailableSystem: AvailableCodeSystem?
    @State private var isLoadingCodeSystems: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Codeagogo").font(.title2)

                GroupBox("Lookup Hotkey") {
                    VStack(alignment: .leading, spacing: 10) {
                        HotKeyRecorderView(
                            keyCode: $hk.keyCode,
                            modifiersRaw: $hk.modifiersRaw
                        )
                        .accessibilityIdentifier("settings.lookupHotkey")

                        Text("Looks up the selected SNOMED CT concept ID.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding(.top, 4)
                }

                GroupBox("Search Hotkey") {
                    VStack(alignment: .leading, spacing: 10) {
                        HotKeyRecorderView(
                            keyCode: $searchHk.keyCode,
                            modifiersRaw: $searchHk.modifiersRaw
                        )
                        .accessibilityIdentifier("settings.searchHotkey")

                        Text("Opens a panel to search and insert SNOMED CT concepts.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding(.top, 4)
                }

                GroupBox("Replace Hotkey") {
                    VStack(alignment: .leading, spacing: 10) {
                        HotKeyRecorderView(
                            keyCode: $replaceHk.keyCode,
                            modifiersRaw: $replaceHk.modifiersRaw
                        )
                        .accessibilityIdentifier("settings.replaceHotkey")

                        Picker("Term format:", selection: $replaceSettings.termFormat) {
                            ForEach(ReplaceTermFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .frame(width: 280)
                        .accessibilityIdentifier("settings.replaceTermFormat")
                        .accessibilityLabel("Replace term format")
                        .accessibilityHint("Select whether to use FSN or PT in the replacement")

                        Toggle("Prefix inactive concepts with \"INACTIVE - \"", isOn: $replaceSettings.prefixInactive)
                            .accessibilityIdentifier("settings.replacePrefixInactive")
                            .accessibilityHint("When enabled, inactive concepts will show INACTIVE - before the term")

                        Text("Replaces selected concept ID with ID | term |")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding(.top, 4)
                }

                GroupBox("ECL Format Hotkey") {
                    VStack(alignment: .leading, spacing: 10) {
                        HotKeyRecorderView(
                            keyCode: $eclFormatHk.keyCode,
                            modifiersRaw: $eclFormatHk.modifiersRaw
                        )
                        .accessibilityIdentifier("settings.eclFormatHotkey")

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

            GroupBox("Additional Code Systems") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Configure code systems for lookup and replace (non-SNOMED codes).")
                        .foregroundStyle(.secondary)
                        .font(.footnote)

                    // List of configured systems with toggle and remove button
                    ForEach($codeSystemSettings.configuredSystems) { $system in
                        HStack {
                            Toggle(system.title, isOn: $system.enabled)
                                .accessibilityIdentifier("settings.codeSystem.\(system.uri)")
                            Spacer()
                            Button(role: .destructive) {
                                codeSystemSettings.removeSystem(uri: system.uri)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(system.title)")
                        }
                    }

                    if codeSystemSettings.configuredSystems.isEmpty {
                        Text("No code systems configured.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .italic()
                    }

                    Divider()

                    // Add new code system from server
                    HStack {
                        Picker("Add:", selection: $selectedAvailableSystem) {
                            Text("Select...").tag(nil as AvailableCodeSystem?)
                            ForEach(availableCodeSystems.filter { !isAlreadyConfigured($0) }) { system in
                                Text(system.title).tag(system as AvailableCodeSystem?)
                            }
                        }
                        .frame(width: 200)
                        .accessibilityIdentifier("settings.addCodeSystemPicker")

                        Button("Add") {
                            if let system = selectedAvailableSystem {
                                codeSystemSettings.addSystem(uri: system.url, title: system.title)
                                selectedAvailableSystem = nil
                            }
                        }
                        .disabled(selectedAvailableSystem == nil)
                        .accessibilityIdentifier("settings.addCodeSystemButton")

                        if isLoadingCodeSystems {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                        }
                    }

                    Button("Refresh from server") {
                        Task { await loadAvailableCodeSystems() }
                    }
                    .accessibilityIdentifier("settings.refreshCodeSystemsButton")
                }
                .padding(.top, 4)
            }
            .onAppear {
                Task { await loadAvailableCodeSystems() }
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
        .frame(width: 520, height: 920)
    }

    // MARK: - Code System Helpers

    /// Checks if a code system is already configured.
    private func isAlreadyConfigured(_ system: AvailableCodeSystem) -> Bool {
        codeSystemSettings.configuredSystems.contains { $0.uri == system.url }
    }

    /// Loads available code systems from the FHIR server.
    private func loadAvailableCodeSystems() async {
        isLoadingCodeSystems = true
        defer { isLoadingCodeSystems = false }

        do {
            let client = OntoserverClient()
            let systems = try await client.getAvailableCodeSystems()
            await MainActor.run {
                self.availableCodeSystems = systems
            }
        } catch {
            AppLog.error(AppLog.network, "Failed to load code systems: \(error.localizedDescription)")
        }
    }
}

