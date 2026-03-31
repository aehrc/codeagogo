#!/bin/bash
# Checks or applies Apache 2.0 license headers to all Swift source files.
#
# Usage:
#   ./scripts/license-header.sh --check   # Verify all files have headers (CI)
#   ./scripts/license-header.sh --apply   # Add headers to files missing them
#
# Exit code: 0 = all files have headers, 1 = missing headers found (--check)

set -euo pipefail

HEADER='// Copyright 2026 Commonwealth Scientific and Industrial Research Organisation (CSIRO)
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
// limitations under the License.'

HEADER_MARKER="Licensed under the Apache License, Version 2.0"

MODE="${1:---check}"

# Find all Swift files, excluding build dirs and SPM checkouts
SWIFT_FILES=$(find Codeagogo CodeagogoTests CodeagogoUITests -name "*.swift" \
    -not -path "*/build/*" \
    -not -path "*/.build/*" \
    -not -path "*/DerivedData/*" \
    -not -path "*/.swiftpm/*" \
    -not -path "*/SourcePackages/*" \
    2>/dev/null | sort)

# Also include root-level Swift files
if [ -f "FHIROptions.swift" ]; then
    SWIFT_FILES="$SWIFT_FILES
FHIROptions.swift"
fi

MISSING=()

for file in $SWIFT_FILES; do
    if ! grep -q "$HEADER_MARKER" "$file" 2>/dev/null; then
        MISSING+=("$file")
    fi
done

if [ "$MODE" = "--apply" ]; then
    if [ ${#MISSING[@]} -eq 0 ]; then
        echo "All ${#SWIFT_FILES[@]} Swift files already have license headers."
        exit 0
    fi

    for file in "${MISSING[@]}"; do
        # Prepend header + blank line to file
        TEMP=$(mktemp)
        echo "$HEADER" > "$TEMP"
        echo "" >> "$TEMP"
        cat "$file" >> "$TEMP"
        mv "$TEMP" "$file"
        echo "Added header: $file"
    done

    echo ""
    echo "Added license headers to ${#MISSING[@]} file(s)."
    exit 0

elif [ "$MODE" = "--check" ]; then
    if [ ${#MISSING[@]} -eq 0 ]; then
        echo "PASS: All Swift files have license headers."
        exit 0
    fi

    echo "FAIL: ${#MISSING[@]} file(s) missing license header:"
    for file in "${MISSING[@]}"; do
        echo "  $file"
    done
    exit 1

else
    echo "Usage: $0 --check | --apply"
    exit 1
fi
