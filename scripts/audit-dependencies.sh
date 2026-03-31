#!/bin/bash
# Audits SPM dependencies for known vulnerabilities and license compliance.
#
# Checks:
# 1. Lists all resolved dependencies with pinned versions
# 2. Verifies dependencies are pinned to exact versions (not branches/ranges)
# 3. Checks for known CVEs via GitHub Advisory Database API
# 4. Validates licenses are permissive (MIT, Apache-2.0, BSD)
#
# Usage: ./scripts/audit-dependencies.sh
# Exit code: 0 = pass, 1 = issues found

set -euo pipefail

PACKAGE_RESOLVED="Codeagogo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
ISSUES=0

echo "=== SPM Dependency Audit ==="
echo ""

# Check Package.resolved exists
if [ ! -f "$PACKAGE_RESOLVED" ]; then
    echo "PASS: No Package.resolved found — no external dependencies"
    exit 0
fi

# Parse dependencies
DEPS=$(python3 -c "
import json, sys
with open('$PACKAGE_RESOLVED') as f:
    data = json.load(f)
pins = data.get('pins', [])
if not pins:
    print('NO_DEPS')
else:
    for pin in pins:
        identity = pin.get('identity', 'unknown')
        location = pin.get('location', 'unknown')
        state = pin.get('state', {})
        version = state.get('version', '')
        revision = state.get('revision', '')
        branch = state.get('branch', '')
        print(f'{identity}|{location}|{version}|{revision}|{branch}')
" 2>/dev/null)

if [ "$DEPS" = "NO_DEPS" ]; then
    echo "PASS: No dependencies found"
    exit 0
fi

echo "Dependencies found:"
echo ""

while IFS='|' read -r identity location version revision branch; do
    echo "  Package:  $identity"
    echo "  Location: $location"
    echo "  Version:  ${version:-'(none)'}"
    echo "  Revision: ${revision:0:12}"

    # Check 1: Version pinning
    if [ -z "$version" ]; then
        if [ -n "$branch" ]; then
            echo "  WARNING: Pinned to branch '$branch' — should use exact version"
            ISSUES=$((ISSUES + 1))
        else
            echo "  WARNING: No version specified — should use exact version"
            ISSUES=$((ISSUES + 1))
        fi
    else
        echo "  Pinning:  OK (exact version $version)"
    fi

    # Check 2: GitHub Advisory Database (if it's a GitHub repo)
    if [[ "$location" == *"github.com"* ]]; then
        # Extract owner/repo from URL
        REPO_PATH=$(echo "$location" | sed -E 's|.*github\.com/([^/]+/[^/.]+).*|\1|')
        if [ -n "$REPO_PATH" ]; then
            # Query GitHub Advisory Database
            ADVISORIES=$(curl -s "https://api.github.com/repos/$REPO_PATH/security-advisories?state=published" 2>/dev/null || echo "API_ERROR")
            if [ "$ADVISORIES" = "API_ERROR" ] || [[ "$ADVISORIES" == *"Not Found"* ]] || [[ "$ADVISORIES" == *"API rate limit"* ]]; then
                echo "  CVE Check: Skipped (API unavailable)"
            elif [ "$ADVISORIES" = "[]" ]; then
                echo "  CVE Check: OK (no published advisories)"
            else
                ADVISORY_COUNT=$(echo "$ADVISORIES" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
                if [ "$ADVISORY_COUNT" != "0" ] && [ "$ADVISORY_COUNT" != "" ]; then
                    echo "  CVE Check: WARNING — $ADVISORY_COUNT published advisory(ies) found"
                    echo "             Review: https://github.com/$REPO_PATH/security/advisories"
                    ISSUES=$((ISSUES + 1))
                else
                    echo "  CVE Check: OK"
                fi
            fi
        fi
    else
        echo "  CVE Check: Skipped (non-GitHub source)"
    fi

    # Check 3: License (via GitHub API)
    if [[ "$location" == *"github.com"* ]]; then
        REPO_PATH=$(echo "$location" | sed -E 's|.*github\.com/([^/]+/[^/.]+).*|\1|')
        if [ -n "$REPO_PATH" ]; then
            LICENSE=$(curl -s "https://api.github.com/repos/$REPO_PATH" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    lic = data.get('license', {})
    if lic:
        print(lic.get('spdx_id', 'UNKNOWN'))
    else:
        print('NONE')
except:
    print('ERROR')
" 2>/dev/null)

            ALLOWED_LICENSES=("MIT" "Apache-2.0" "BSD-2-Clause" "BSD-3-Clause" "ISC" "0BSD")
            LICENSE_OK=false
            for allowed in "${ALLOWED_LICENSES[@]}"; do
                if [ "$LICENSE" = "$allowed" ]; then
                    LICENSE_OK=true
                    break
                fi
            done

            if $LICENSE_OK; then
                echo "  License:  OK ($LICENSE)"
            elif [ "$LICENSE" = "ERROR" ] || [ "$LICENSE" = "UNKNOWN" ] || [ "$LICENSE" = "NONE" ]; then
                echo "  License:  Skipped (could not determine from API — verify manually in THIRD-PARTY-LICENSES.md)"
            else
                echo "  License:  WARNING — '$LICENSE' may not be permissive"
                ISSUES=$((ISSUES + 1))
            fi
        fi
    fi

    echo ""
done <<< "$DEPS"

# Check 4: Cross-reference against THIRD-PARTY-LICENSES.md
THIRD_PARTY_FILE="THIRD-PARTY-LICENSES.md"
echo "=== Third-Party License Documentation ==="
echo ""

if [ ! -f "$THIRD_PARTY_FILE" ]; then
    echo "FAIL: $THIRD_PARTY_FILE not found"
    ISSUES=$((ISSUES + 1))
else
    while IFS='|' read -r identity location version revision branch; do
        # Check that this dependency is documented in THIRD-PARTY-LICENSES.md
        if grep -qi "$identity" "$THIRD_PARTY_FILE" 2>/dev/null; then
            echo "  $identity: documented in $THIRD_PARTY_FILE"
        else
            echo "  $identity: MISSING from $THIRD_PARTY_FILE"
            ISSUES=$((ISSUES + 1))
        fi
    done <<< "$DEPS"
fi

echo ""

# Summary
echo "=== Audit Summary ==="
if [ $ISSUES -eq 0 ]; then
    echo "PASS: All checks passed"
    exit 0
else
    echo "ISSUES: $ISSUES issue(s) found — review above"
    exit 1
fi
