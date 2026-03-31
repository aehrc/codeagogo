# first-launch-welcome Specification

## Purpose
Show a one-time welcome screen on first launch that invites users to join the Codeagogo mailing list, request features on GitHub Issues, and star the GitHub repo. The app opens external URLs and never collects, stores, or transmits personal data.

## Requirements
### Requirement: Welcome screen shown on first launch
The system SHALL display a welcome screen the first time the app is launched after installation.

#### Scenario: First launch shows welcome
- **WHEN** the app launches and `welcome.hasShown` is not set in UserDefaults
- **THEN** the system displays the welcome screen as a standalone window

#### Scenario: Subsequent launches skip welcome
- **WHEN** the app launches and `welcome.hasShown` is `true` in UserDefaults
- **THEN** the system does not display the welcome screen

### Requirement: Welcome screen shown on upgrade for existing users
The system SHALL display the welcome screen for existing users upgrading to a version that includes this feature, if they have not previously seen it.

#### Scenario: Upgrade triggers welcome
- **WHEN** the app launches after an upgrade and `welcome.hasShown` does not exist in UserDefaults
- **THEN** the system displays the welcome screen

### Requirement: Welcome screen has GitHub star invitation
The welcome screen SHALL include an invitation to star the project on GitHub with a button that opens the repository URL `https://github.com/aehrc/codeagogo`.

#### Scenario: Open GitHub button
- **WHEN** the user clicks the "Star on GitHub" button on the welcome screen
- **THEN** the system opens `https://github.com/aehrc/codeagogo` in the user's default browser

### Requirement: Welcome screen has mailing list invitation
The welcome screen SHALL include an encouraging invitation to join the Codeagogo mailing list with a button that opens the Mailman subscription page at `https://lists.csiro.au/mailman3/lists/codeagogo.lists.csiro.au/`.

#### Scenario: User clicks join mailing list
- **WHEN** the user clicks the "Join Mailing List" button on the welcome screen
- **THEN** the system opens `https://lists.csiro.au/mailman3/lists/codeagogo.lists.csiro.au/` in the user's default browser

#### Scenario: No personal data collected by the app
- **WHEN** the user clicks the "Join Mailing List" button
- **THEN** the app does not collect, store, or transmit any personal data — all data entry happens on the external Mailman page

### Requirement: Welcome screen has feature request invitation
The welcome screen SHALL include a button to request features or report bugs that opens the GitHub Issues page at `https://github.com/aehrc/codeagogo/issues`.

#### Scenario: User clicks request a feature
- **WHEN** the user clicks the "Request a Feature" button on the welcome screen
- **THEN** the system opens `https://github.com/aehrc/codeagogo/issues` in the user's default browser

### Requirement: Welcome screen dismissal
The welcome screen SHALL include a "Get Started" button to dismiss the screen and mark it as shown.

#### Scenario: Dismiss marks as shown
- **WHEN** the user clicks the "Get Started" button on the welcome screen
- **THEN** `welcome.hasShown` is set to `true` in UserDefaults and the welcome window closes

### Requirement: Welcome screen dismissal persists regardless of method
The system SHALL record that the welcome screen has been shown, regardless of how the user dismisses it.

#### Scenario: Closing window marks as shown
- **WHEN** the user closes the welcome window by any means (button, window close, Cmd+W)
- **THEN** `welcome.hasShown` is set to `true` in UserDefaults

### Requirement: No personal data stored in the app
The system SHALL NOT collect, store, or transmit any personal data. Mailing list subscription is handled entirely by the external Mailman service.

#### Scenario: No personal data in UserDefaults
- **GIVEN** the welcome screen has been shown
- **THEN** no personal data keys (name, email) exist in UserDefaults

### Requirement: Welcome screen privacy notice
The welcome screen SHALL display a brief note explaining that the mailing list is managed externally and the app does not collect personal information.

#### Scenario: Privacy text visible
- **WHEN** the welcome screen is displayed
- **THEN** a note is visible explaining that the mailing list is managed by CSIRO and the app collects no personal data

### Requirement: About window credits
The About window SHALL display credits with links to the mailing list, GitHub Issues, and GitHub repository.

#### Scenario: Credits visible in About
- **WHEN** the user opens the About window
- **THEN** clickable links for the mailing list, feature requests, and GitHub repository are visible
