#!/bin/bash
# Context Loading Utilities for Hierarchical Context Management

GLOBAL_CONTEXT_DIR="/workspace/context/global"
USER_CONTEXT_DIR="$HOME/.claude"
PROJECT_CONTEXT_FILE="./CLAUDE.md"

# Function to load global context
load_global_context() {
    local context=""

    # Load CLAUDE.md
    if [[ -f "$GLOBAL_CONTEXT_DIR/CLAUDE.md" ]]; then
        context+="\n=== CLAUDE RULES ===\n$(cat "$GLOBAL_CONTEXT_DIR/CLAUDE.md")\n"
    fi

    # Load CCFOREVER.md
    if [[ -f "$GLOBAL_CONTEXT_DIR/CCFOREVER.md" ]]; then
        context+="\n=== CC FOREVER INSTRUCTIONS ===\n$(cat "$GLOBAL_CONTEXT_DIR/CCFOREVER.md")\n"
    fi

    echo -e "$context"
}

# Function to load user context
load_user_context() {
    local context=""

    if [[ -f "$USER_CONTEXT_DIR/CLAUDE.md" ]]; then
        context+="\n=== USER PREFERENCES ===\n$(cat "$USER_CONTEXT_DIR/CLAUDE.md")\n"
    fi

    echo -e "$context"
}

# Function to load project context
load_project_context() {
    local context=""

    if [[ -f "$PROJECT_CONTEXT_FILE" ]]; then
        context+="\n=== PROJECT CONTEXT ===\n$(cat "$PROJECT_CONTEXT_FILE")\n"
    fi

    echo -e "$context"
}

# Function to load mandatory agents
load_mandatory_agents() {
    local context=""

    # Load doc-planner.md
    if [[ -f "/workspace/agents/doc-planner.md" ]]; then
        context+="\n=== DOC PLANNER AGENT ===\n$(cat /workspace/agents/doc-planner.md)\n"
    fi

    # Load microtask-breakdown.md
    if [[ -f "/workspace/agents/microtask-breakdown.md" ]]; then
        context+="\n=== MICROTASK BREAKDOWN AGENT ===\n$(cat /workspace/agents/microtask-breakdown.md)\n"
    fi

    echo -e "$context"
}

# Function to load all context in hierarchy
load_all_context() {
    local context=""

    # Load in hierarchical order
    context+="$(load_global_context)"
    context+="$(load_user_context)"
    context+="$(load_project_context)"
    context+="$(load_mandatory_agents)"

    # Add session overrides from environment
    if [[ -n "$CLAUDE_SESSION_CONTEXT" ]]; then
        context+="\n=== SESSION OVERRIDES ===\n$CLAUDE_SESSION_CONTEXT\n"
    fi

    echo -e "$context"
}

# Function to validate context files
validate_context() {
    local validation_passed=true

    echo "🔍 Validating context files..."

    # Check global context files
    for file in CLAUDE.md CCFOREVER.md; do
        if [[ -f "$GLOBAL_CONTEXT_DIR/$file" ]]; then
            echo "✅ Global: $file"
        else
            echo "❌ Missing global: $file"
            validation_passed=false
        fi
    done

    # Check mandatory agents
    for agent in doc-planner.md microtask-breakdown.md; do
        if [[ -f "/workspace/agents/$agent" ]]; then
            echo "✅ Mandatory agent: $agent"
        else
            echo "⚠️ Missing mandatory agent: $agent"
        fi
    done

    # Check user context (optional)
    if [[ -f "$USER_CONTEXT_DIR/CLAUDE.md" ]]; then
        echo "✅ User context found"
    else
        echo "ℹ️ No user context (optional)"
    fi

    # Check project context (optional)
    if [[ -f "$PROJECT_CONTEXT_FILE" ]]; then
        echo "✅ Project context found"
    else
        echo "ℹ️ No project context (optional)"
    fi

    if [[ "$validation_passed" == true ]]; then
        echo "✅ Context validation passed"
        return 0
    else
        echo "❌ Context validation failed"
        return 1
    fi
}

# Function to show context hierarchy
show_context_hierarchy() {
    echo "📚 Context Loading Hierarchy:"
    echo "============================"
    echo "1. Global Context (/workspace/context/global/)"
    echo "   - CLAUDE.md (Core Configuration)"
    echo "   - CCFOREVER.md (Quality Assurance)"
    echo ""
    echo "2. User Preferences (~/.claude/CLAUDE.md)"
    echo "   - Personal coding preferences"
    echo "   - User-specific configurations"
    echo ""
    echo "3. Project Context (./CLAUDE.md)"
    echo "   - Project-specific instructions"
    echo "   - Local overrides and additions"
    echo ""
    echo "4. Mandatory Agents (/workspace/agents/)"
    echo "   - doc-planner.md (Required)"
    echo "   - microtask-breakdown.md (Required)"
    echo ""
    echo "5. Session Overrides (\$CLAUDE_SESSION_CONTEXT)"
    echo "   - Runtime environment variables"
    echo "   - Temporary session modifications"
}

# Export functions
export -f load_global_context
export -f load_user_context
export -f load_project_context
export -f load_mandatory_agents
export -f load_all_context
export -f validate_context
export -f show_context_hierarchy