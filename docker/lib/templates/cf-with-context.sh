#!/bin/bash
# Claude Flow wrapper that auto-loads context files

# Source context loading utilities
source /workspace/scripts/lib/context-loader.sh

# Function to load and prepare context
load_context_for_claude_flow() {
    local context=""

    # Load full context hierarchy
    context=$(load_all_context)

    # Clean up the context (remove extra whitespace)
    echo -e "$context" | sed '/^$/N;/^\n$/d'
}

# Function to validate context before execution
validate_before_execution() {
    if ! validate_context >/dev/null 2>&1; then
        echo "⚠️ Context validation failed. Continuing with available context..."
    fi
}

# Main execution logic
main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <claude-flow-command> [args...]"
        echo ""
        echo "Examples:"
        echo "  $0 swarm 'Build a web app'"
        echo "  $0 hive-mind spawn --agents 10 'Optimize performance'"
        echo "  $0 verify init strict"
        echo ""
        echo "This wrapper automatically loads context from:"
        show_context_hierarchy
        exit 0
    fi

    # Validate context
    validate_before_execution

    local command="$1"
    shift

    # Load context
    local context
    context=$(load_context_for_claude_flow)

    echo "🔄 Loading context and executing Claude Flow..."

    # Execute based on command type
    case "$command" in
        "swarm")
            npx claude-flow@alpha swarm "$@" --claude <<< "$context"
            ;;
        "hive-mind"|"hive")
            # hive-mind doesn't like stdin input
            echo "🚀 Running Claude Flow hive-mind..."
            if [[ "$1" == "spawn" ]]; then
                npx claude-flow@alpha hive-mind spawn "${@:2}" --claude
            else
                npx claude-flow@alpha hive-mind spawn "$@" --claude
            fi
            ;;
        "verify")
            npx claude-flow@alpha verify "$@"
            ;;
        "truth")
            npx claude-flow@alpha truth "$@"
            ;;
        "pair")
            npx claude-flow@alpha pair "$@"
            ;;
        *)
            npx claude-flow@alpha "$command" "$@" --claude <<< "$context"
            ;;
    esac
}

# Execute with all arguments
main "$@"