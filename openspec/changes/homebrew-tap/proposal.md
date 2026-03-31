## Why

Homebrew is the dominant package manager on macOS. A Homebrew tap lets users install and update Codeagogo with a single command, which is the expected experience for developer and clinical informatician audiences.

## What Changes

- Add a Homebrew Cask formula at `Casks/codeagogo.rb` in this repository
- Formula points to the signed `.dmg` on GitHub Releases
- Document the installation instructions in README and on the website

## Capabilities

### New Capabilities
- `homebrew-tap`: Homebrew Cask formula in the existing repository, enabling `brew tap aehrc/codeagogo https://github.com/aehrc/codeagogo && brew install --cask codeagogo`. Formula references the GitHub Releases download URL and SHA256 hash of the signed `.dmg`.

### Modified Capabilities
<!-- None -->

## Impact

- **New file**: `Casks/codeagogo.rb`
- **README.md**: Updated with Homebrew installation instructions
- **Release process**: Each release needs the Cask formula updated with new version and SHA256
- **No new repositories** — formula lives in the existing mac app repo
- **No code changes to Codeagogo itself**

## Prerequisites

- `macos-code-signing` change completed (signed `.dmg` available)
- At least one GitHub Release published with the signed `.dmg`

## Open Questions

1. **Formula update automation**: Manually update the formula per release, or automate via GitHub Actions in the release workflow?
2. **Submission to homebrew-cask main**: Worth doing once we have user numbers. Requires minimum notability — revisit after launch.
