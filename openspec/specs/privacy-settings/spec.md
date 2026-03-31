# privacy-settings Specification

## Purpose
Provide a Privacy section in Settings that displays the anonymous install ID, allows resetting it, shows a link to re-display the welcome screen, and explains how anonymous metrics work.

## Requirements
### Requirement: Privacy section in Settings
The Settings view SHALL include a "Privacy" section displaying anonymous metrics information and a welcome screen control.

#### Scenario: Privacy section visible
- **WHEN** the user opens Settings
- **THEN** a "Privacy" GroupBox is visible containing install ID display, reset button, welcome screen button, and explanatory text

### Requirement: Display anonymous install ID
The Privacy section SHALL display the current anonymous install ID as read-only text.

#### Scenario: Install ID displayed
- **WHEN** the user views the Privacy section in Settings
- **THEN** the current install ID is displayed in a read-only text field with a label explaining its purpose

### Requirement: Reset install ID button
The Privacy section SHALL include a button to reset the anonymous install ID.

#### Scenario: Reset button generates new ID
- **WHEN** the user clicks "Reset Anonymous ID" in the Privacy section
- **THEN** a new UUID is generated, stored in UserDefaults, and displayed in the Settings view

### Requirement: Show welcome screen again
The Privacy section SHALL include a button to re-show the welcome screen.

#### Scenario: Re-show welcome
- **WHEN** the user clicks "Show Welcome Screen" in the Privacy section
- **THEN** the system sets `welcome.hasShown` to `false` and opens the welcome window

### Requirement: Privacy explanation text
The Privacy section SHALL include explanatory text about what the anonymous ID is and how it's used.

#### Scenario: Explanation text content
- **WHEN** the user views the Privacy section
- **THEN** text is displayed explaining: "A random anonymous identifier is included in terminology server requests to help count active installations. It contains no personal information. This app does not collect or store any personal data."
