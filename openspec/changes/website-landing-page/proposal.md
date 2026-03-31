## Why

Codeagogo needs a public-facing page with download links, installation instructions, and screenshots. GitHub Pages is the simplest option — no separate infrastructure, deploys from the repo, and lives at the project URL.

## What Changes

- Add a `docs/` directory with a GitHub Pages site (static HTML/CSS)
- Landing page includes: app description, screenshots, download link (GitHub Releases), installation instructions, mailing list link, feature request link, GitHub repo link
- Enable GitHub Pages in repo settings (deploy from `docs/` on `main`)

## Capabilities

### New Capabilities
- `website-landing-page`: Static GitHub Pages site in `docs/` with app overview, download links to GitHub Releases, installation instructions, mailing list and GitHub links.

### Modified Capabilities
<!-- None -->

## Impact

- **New directory**: `docs/` with `index.html`, CSS, and screenshot images
- **No code changes to Codeagogo itself**
- **GitHub repo setting**: Enable Pages from `docs/` folder on `main` branch

## Prerequisites

- At least one release published on GitHub Releases
- App screenshots available

## Design Decisions

1. **GitHub Pages over separate hosting**: Zero infrastructure, auto-deploys on push, lives at `https://aehrc.github.io/codeagogo/`
2. **`docs/` folder over `gh-pages` branch**: Simpler — everything in one branch, no orphan branch to maintain
3. **Static HTML over Jekyll**: Keeps it simple, no build step, no Ruby dependency
