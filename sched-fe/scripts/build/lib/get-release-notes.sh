#!/bin/bash

# ========================================
# Release Notes Extractor
# ========================================
#
# This script extracts the "Next Release" section from RELEASE_NOTES.md
# Used by all build scripts to ensure consistent release notes across platforms
#
# Usage:
#   source scripts/lib/get-release-notes.sh
#   NOTES=$(get_release_notes)
#
# ========================================

get_release_notes() {
    local RELEASE_NOTES_FILE="RELEASE_NOTES.md"

    if [ ! -f "$RELEASE_NOTES_FILE" ]; then
        echo "⚠️  RELEASE_NOTES.md not found. Using default notes."
        echo ""
        echo "📝 Please update RELEASE_NOTES.md before the next release"
        return
    fi

    # Extract content between "## Next Release" and "---" or next "##"
    # This captures the Changes, Features, and Bug Fixes sections
    local notes=$(awk '
        /^## Next Release/ { capture=1; next }
        /^---/ && capture { exit }
        /^## / && capture && !/^## Next Release/ { exit }
        capture && /^### / {
            section=$0
            gsub(/^### /, "", section)
            printf "\n%s:\n", section
            next
        }
        capture && /^- / {
            print $0
        }
    ' "$RELEASE_NOTES_FILE")

    if [ -z "$notes" ]; then
        echo "⚠️  No release notes found in 'Next Release' section"
        echo ""
        echo "📝 Please update RELEASE_NOTES.md with your changes"
        return
    fi

    echo "$notes"
}

# Function to format notes for Firebase (multiline string)
format_notes_firebase() {
    local version="$1"
    local build="$2"
    local bump_type="$3"
    local notes=$(get_release_notes)

    cat << EOF
Version $version (Build $build)
$notes

📦 Build type: $bump_type
🗓️  Release date: $(date '+%Y-%m-%d %H:%M')
EOF
}

# Function to format notes for GitHub (markdown)
format_notes_github() {
    local version="$1"
    local notes=$(get_release_notes)

    cat << EOF
## TCS Pace Scheduler v$version
$notes

---

🤖 Generated with automated release workflow
EOF
}
