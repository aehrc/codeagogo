#!/bin/bash
# Installs a pre-commit hook that runs gitleaks to prevent secrets from being committed.
#
# Usage: ./scripts/install-hooks.sh
#
# Prerequisites: gitleaks must be installed (brew install gitleaks)

set -euo pipefail

HOOK_DIR="$(git rev-parse --git-dir)/hooks"
HOOK_FILE="$HOOK_DIR/pre-commit"

# Check gitleaks is installed
if ! command -v gitleaks &> /dev/null; then
    echo "Error: gitleaks is not installed."
    echo "Install it with: brew install gitleaks"
    exit 1
fi

# Create hooks directory if needed
mkdir -p "$HOOK_DIR"

# Write pre-commit hook
cat > "$HOOK_FILE" << 'HOOK'
#!/bin/bash
# Pre-commit hook: scan staged changes for secrets using gitleaks

if command -v gitleaks &> /dev/null; then
    gitleaks protect --staged --config .gitleaks.toml --verbose
    if [ $? -ne 0 ]; then
        echo ""
        echo "Secrets detected in staged changes. Commit blocked."
        echo "Review the findings above and remove any secrets before committing."
        exit 1
    fi
else
    echo "Warning: gitleaks not installed, skipping secrets scan"
    echo "Install with: brew install gitleaks"
fi
HOOK

chmod +x "$HOOK_FILE"
echo "Pre-commit hook installed at $HOOK_FILE"
echo "Staged changes will be scanned for secrets before each commit."
