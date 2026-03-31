// Copyright 2026 Commonwealth Scientific and Industrial Research Organisation (CSIRO)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import ServiceManagement

/// The first-launch welcome screen displayed once after installation or upgrade.
///
/// Presents the app name and description, then encourages users to:
/// - Join the Codeagogo mailing list (opens external Mailman page)
/// - Star the GitHub repository
///
/// No personal data is collected by the app. Both CTAs open external URLs
/// in the user's default browser.
struct WelcomeView: View {
    /// Callback invoked when the user dismisses the welcome screen.
    var onDismiss: () -> Void = {}

    /// Whether to launch at login — checked by default, applied on dismiss.
    @State private var launchAtLogin: Bool = true

    /// The mailing list subscription URL.
    static let mailingListURL = URL(string: "https://lists.csiro.au/mailman3/lists/codeagogo.lists.csiro.au/")!

    /// The GitHub repository URL.
    static let gitHubURL = URL(string: "https://github.com/aehrc/codeagogo")!

    /// The GitHub issues URL for feature requests.
    static let gitHubIssuesURL = URL(string: "https://github.com/aehrc/codeagogo/issues")!

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)

                Text("Welcome to Codeagogo")
                    .font(.title)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("welcome.title")

                Text("A macOS utility for looking up, searching, and annotating clinical terminology codes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 32)

            // MARK: - Mailing List CTA
            VStack(spacing: 8) {
                Text("Join the Community")
                    .font(.headline)
                    .accessibilityIdentifier("welcome.mailingListHeading")

                Text("We'd love to know you're out there! Sign up to our mailing list so we know who's using Codeagogo — and so we can let you know about new features and updates. It only takes a moment.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                Button(action: {
                    NSWorkspace.shared.open(Self.mailingListURL)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                        Text("Join Mailing List")
                    }
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("welcome.joinMailingList")
                .accessibilityLabel("Join Mailing List")
                .accessibilityHint("Opens the mailing list subscription page in your browser")
            }
            .padding(.vertical, 16)

            // MARK: - GitHub CTAs
            VStack(spacing: 8) {
                Text("Got an idea for a feature, or found a bug? Let us know on GitHub. Please star our GitHub project if you find this tool useful — it only takes a second and makes a real difference.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                HStack(spacing: 12) {
                    Button(action: {
                        NSWorkspace.shared.open(Self.gitHubIssuesURL)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                            Text("Request a Feature")
                        }
                    }
                    .controlSize(.regular)
                    .accessibilityIdentifier("welcome.requestFeature")
                    .accessibilityLabel("Request a Feature")
                    .accessibilityHint("Opens the GitHub issues page in your browser")

                    Button(action: {
                        NSWorkspace.shared.open(Self.gitHubURL)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                            Text("Star on GitHub")
                        }
                    }
                    .controlSize(.regular)
                    .accessibilityIdentifier("welcome.starOnGitHub")
                    .accessibilityLabel("Star on GitHub")
                    .accessibilityHint("Opens the GitHub repository in your browser")
                }
            }
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 32)

            // MARK: - Privacy Note
            Text("This app does not collect or store any personal data. The mailing list is managed by CSIRO — you can subscribe and unsubscribe at any time.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.vertical, 12)
                .accessibilityIdentifier("welcome.privacyNote")

            // MARK: - Launch at Login
            Toggle("Launch Codeagogo when you log in", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.callout)
                .padding(.horizontal, 40)
                .padding(.bottom, 12)
                .accessibilityIdentifier("welcome.launchAtLogin")

            // MARK: - Dismiss
            Button("Get Started") {
                applyLaunchAtLogin()
                onDismiss()
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("welcome.getStarted")
            .accessibilityLabel("Get Started")
            .accessibilityHint("Closes the welcome screen")
            .padding(.bottom, 24)
        }
        .frame(width: 460)
    }

    /// Registers or unregisters as a login item based on the user's choice.
    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Non-fatal — user can change it later in Settings
        }
    }
}
