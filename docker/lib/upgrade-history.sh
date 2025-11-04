#!/bin/bash
# upgrade-history.sh - Track extension upgrade history

HISTORY_DIR="$HOME/.local/share/extension-manager"
HISTORY_FILE="$HISTORY_DIR/upgrade-history.log"

# Initialize history file
init_upgrade_history() {
    mkdir -p "$HISTORY_DIR"
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo "# Extension Upgrade History" > "$HISTORY_FILE"
        echo "# Format: TIMESTAMP|EXTENSION|OLD_VERSION|NEW_VERSION|STATUS|DURATION" >> "$HISTORY_FILE"
    fi
}

# Record upgrade in history
# Usage: record_upgrade "extension-name" "old-version" "new-version" "status" "duration"
record_upgrade() {
    local extension="$1"
    local old_version="$2"
    local new_version="$3"
    local status="$4"
    local duration="$5"

    init_upgrade_history

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "${timestamp}|${extension}|${old_version}|${new_version}|${status}|${duration}s" >> "$HISTORY_FILE"
}

# Show upgrade history
# Usage: show_upgrade_history [extension-name] [limit]
show_upgrade_history() {
    local extension="${1:-}"
    local limit="${2:-10}"

    init_upgrade_history

    if [[ ! -f "$HISTORY_FILE" ]]; then
        print_warning "No upgrade history found"
        return 0
    fi

    print_header "Upgrade History"

    if [[ -n "$extension" ]]; then
        print_status "Showing last ${limit} upgrades for ${extension}:"
        grep "|${extension}|" "$HISTORY_FILE" | tail -n "$limit" | column -t -s '|'
    else
        print_status "Showing last ${limit} upgrades:"
        grep -v '^#' "$HISTORY_FILE" | tail -n "$limit" | column -t -s '|'
    fi
}

# Export functions
export -f init_upgrade_history
export -f record_upgrade
export -f show_upgrade_history
