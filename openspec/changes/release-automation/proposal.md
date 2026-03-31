## Why

Manual release processes are error-prone and slow. A GitHub Actions workflow that builds, signs, packages, and publishes macOS releases ensures consistent, reproducible releases and removes the bus factor of needing a specific person's machine.

## What Changes

- Add a GitHub Actions workflow triggered by version tags (e.g. `v1.0.0`)
- Build, sign with Developer ID, notarize, staple, package as `.dmg`
- Create a GitHub Release with the `.dmg` attached and auto-generated release notes
- Update Homebrew tap formula (if automated)

## Capabilities

### New Capabilities
- `release-automation`: GitHub Actions workflow that produces a signed, notarized macOS `.dmg` from a version tag push. Creates a GitHub Release with the artifact attached.

### Modified Capabilities
<!-- None -->

## Impact

- **New files**: `.github/workflows/release.yml`, release documentation
- **Secrets required**: Apple Developer ID cert + password, Apple API key for notarytool
- **No code changes** — CI/CD only
- **No new dependencies**

## Prerequisites

- `macos-code-signing` change completed (signing script exists to call)
- GitHub repo secrets configured for signing certificate
- Apple signing credentials available in CI

## Open Questions

1. **Self-hosted vs GitHub runners**: macOS signing may need a self-hosted runner if the certificate can't be installed in CI. GitHub-hosted macOS runners work but are slower and more expensive for private repos.
2. **Release notes**: Auto-generate from CHANGELOG.md or write manually per release?
3. **Depends on open/closed source decision**: Free CI/CD minutes for public repos; limited for private.
