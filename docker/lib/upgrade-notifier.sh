#!/bin/bash
# upgrade-notifier.sh - Notify users of available upgrades on login

check_and_notify_upgrades() {
    # Only check once per day
    local last_check_file="$HOME/.local/share/extension-manager/last-upgrade-check"
    local current_date
    current_date=$(date +%Y-%m-%d)

    if [[ -f "$last_check_file" ]]; then
        local last_check
        last_check=$(cat "$last_check_file")
        if [[ "$last_check" == "$current_date" ]]; then
            return 0
        fi
    fi

    # Check for updates (silently)
    local updates_available=0

    # For mise-managed tools
    if command -v mise >/dev/null 2>&1; then
        if mise outdated 2>/dev/null | grep -q .; then
            updates_available=1
        fi
    fi

    if [[ $updates_available -eq 1 ]]; then
        echo ""
        echo "═══════════════════════════════════════════════════════"
        echo "  Extension Updates Available"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        echo "  Run: extension-manager check-updates"
        echo "  To upgrade: extension-manager upgrade-all"
        echo ""
    fi

    # Update last check date
    mkdir -p "$(dirname "$last_check_file")"
    echo "$current_date" > "$last_check_file"
}

# Add to .bashrc if not already present
add_to_bashrc() {
    local bashrc="$HOME/.bashrc"
    local marker="# Extension upgrade notifier"

    if ! grep -q "$marker" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" << 'EOF'

# Extension upgrade notifier
# Note: This file is sourced from ~/.bashrc, so it refers to itself
# No action needed - the sourcing happens in bashrc which should reference this file at /docker/lib/upgrade-notifier.sh
EOF
    fi
}
