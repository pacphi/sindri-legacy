#!/bin/bash
# Agent Discovery Utilities
# Functions for finding and loading agents with proper validation

# Function to count total agents
count_agents() {
    find /workspace/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' '
}

# Function to search agents by name attribute
search_agents_by_name() {
    local search_term="$1"
    if [[ -z "$search_term" ]]; then
        echo "Usage: search_agents_by_name <search_term>"
        return 1
    fi

    # Search through agent files and check if name contains search term
    find /workspace/agents -name "*.md" 2>/dev/null | while read -r file; do
        local name
        name=$(get_agent_name "$file")
        if [[ -n "$name" ]] && echo "$name" | grep -q -i "$search_term"; then
            echo "$file"
        fi
    done | sort | uniq
}

# Function to validate agent file format
validate_agent_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    # Check for required fields according to Claude Code sub-agent format
    local has_name=false
    local has_description=false

    if grep -q "^name:" "$file" 2>/dev/null; then
        has_name=true
    fi

    if grep -q "^description:" "$file" 2>/dev/null || grep -q "# " "$file" 2>/dev/null; then
        has_description=true
    fi

    if [[ "$has_name" == true ]]; then
        echo "✅ Valid agent file: $file"
        return 0
    else
        echo "⚠️ Missing required 'name:' field: $file"
        return 1
    fi
}

# Function to get agent name from file
get_agent_name() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    grep "^name:" "$file" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

# Function to get agent description from file
get_agent_description() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Try to get description field first
    local desc
    desc=$(grep "^description:" "$file" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    if [[ -n "$desc" ]]; then
        echo "$desc"
        return 0
    fi

    # Fallback to first heading
    grep "^# " "$file" 2>/dev/null | head -1 | sed 's/^# //'
}

# Function to sample random agents
sample_agents() {
    local count=${1:-5}
    find /workspace/agents -name "*.md" 2>/dev/null | shuf | head -"$count"
}

# Function to list agents by category
list_agents_by_category() {
    local category="$1"
    if [[ -z "$category" ]]; then
        echo "Available categories:"
        find /workspace/agents -type d 2>/dev/null | sed 's|/workspace/agents/||' | grep -v "^$" | sort
        return 0
    fi

    find "/workspace/agents/$category" -name "*.md" 2>/dev/null | sort
}

# Function to search for specific functionality
find_agents_with_functionality() {
    local functionality="$1"
    if [[ -z "$functionality" ]]; then
        echo "Usage: find_agents_with_functionality <functionality>"
        return 1
    fi

    find /workspace/agents -name "*${functionality}*" 2>/dev/null
}

# Function to search agents by content
search_agents_by_content() {
    local search_term="$1"
    if [[ -z "$search_term" ]]; then
        echo "Usage: search_agents_by_content <search_term>"
        return 1
    fi

    grep -r -l -i "$search_term" /workspace/agents/ 2>/dev/null | grep "\.md$"
}

# Function to get agent metadata in structured format
get_agent_metadata() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    local name description tags
    name=$(get_agent_name "$file")
    description=$(get_agent_description "$file")
    tags=$(grep "^tags:" "$file" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    echo "File: $file"
    echo "Name: ${name:-"Not specified"}"
    echo "Description: ${description:-"Not specified"}"
    if [[ -n "$tags" ]]; then
        echo "Tags: $tags"
    fi
}

# Function to list all agents with metadata
list_all_agents_with_metadata() {
    local format=${1:-"simple"}

    find /workspace/agents -name "*.md" 2>/dev/null | while read -r file; do
        if [[ "$format" == "detailed" ]]; then
            echo "================================"
            get_agent_metadata "$file"
        else
            local name description
            name=$(get_agent_name "$file")
            description=$(get_agent_description "$file")
            printf "%-30s %s\n" "${name:-$(basename "$file" .md)}" "${description:-"No description"}"
        fi
    done
}

# Function to find agents by tags
find_agents_by_tag() {
    local tag="$1"
    if [[ -z "$tag" ]]; then
        echo "Usage: find_agents_by_tag <tag>"
        return 1
    fi

    grep -r "tags:" /workspace/agents/ 2>/dev/null | grep -i "$tag" | cut -d: -f1 | sort | uniq
}

# Function to validate all agents in workspace
validate_all_agents() {
    local errors=0
    local total=0
    local temp_errors="/tmp/agent_errors_$$"

    echo "🔍 Validating all agents..."

    # Process files and track counts properly
    while IFS= read -r file; do
        total=$((total + 1))
        if ! validate_agent_file "$file" >/dev/null 2>&1; then
            errors=$((errors + 1))
            echo "❌ $(basename "$file"): Missing required fields" | tee -a "$temp_errors"
        fi
    done < <(find /workspace/agents -name "*.md" 2>/dev/null)

    # Display summary
    if [[ $total -eq 0 ]]; then
        echo "❌ No agents found to validate"
    elif [[ $errors -eq 0 ]]; then
        echo "✅ All $total agents validated successfully"
    else
        echo ""
        echo "⚠️ Found $errors issues in $total agents"
        echo ""
        echo "Summary of validation errors:"
        if [[ -f "$temp_errors" ]]; then
            cat "$temp_errors"
            rm -f "$temp_errors"
        fi
    fi
}

# Function to create agent index for faster searching
create_agent_index() {
    local index_file="/workspace/.agent-index"
    echo "📝 Creating agent search index..."

    {
        find /workspace/agents -name "*.md" 2>/dev/null | while read -r file; do
            local name description tags
            name=$(get_agent_name "$file")
            description=$(get_agent_description "$file")
            tags=$(grep "^tags:" "$file" 2>/dev/null | cut -d: -f2-)

            echo "$file|${name:-}|${description:-}|${tags:-}"
        done
    } > "$index_file"

    echo "✅ Agent index created at $index_file"
}

# Function to search using the index
search_agent_index() {
    local search_term="$1"
    local index_file="/workspace/.agent-index"

    if [[ -z "$search_term" ]]; then
        echo "Usage: search_agent_index <search_term>"
        return 1
    fi

    if [[ ! -f "$index_file" ]]; then
        echo "Index not found. Creating..."
        create_agent_index
    fi

    grep -i "$search_term" "$index_file" | while IFS='|' read -r file name description tags; do
        echo "File: $file"
        echo "Name: $name"
        echo "Description: $description"
        if [[ -n "$tags" ]]; then
            echo "Tags: $tags"
        fi
        echo "---"
    done
}

# Function to get usage statistics
get_agent_stats() {
    local total_agents total_categories total_with_descriptions total_with_tags

    total_agents=$(count_agents)
    total_categories=$(find /workspace/agents -type d 2>/dev/null | grep -v "^/workspace/agents$" | wc -l)
    total_with_descriptions=$(find /workspace/agents -name "*.md" -exec grep -l "^description:" {} \; 2>/dev/null | wc -l)
    total_with_tags=$(find /workspace/agents -name "*.md" -exec grep -l "^tags:" {} \; 2>/dev/null | wc -l)

    echo "📊 Agent Statistics"
    echo "==================="
    echo "Total agents: $total_agents"
    echo "Categories: $total_categories"
    echo "With descriptions: $total_with_descriptions"
    echo "With tags: $total_with_tags"
    echo "Coverage: $((total_with_descriptions * 100 / total_agents))% have descriptions"
}

# Function to find duplicate agents (by name)
find_duplicate_agents() {
    echo "🔍 Checking for duplicate agents..."

    local temp_file="/tmp/agent_names_$$"
    local dup_file="/tmp/agent_dups_$$"

    # Collect all agent names and files
    find /workspace/agents -name "*.md" 2>/dev/null | while read -r file; do
        local name
        name=$(get_agent_name "$file")
        if [[ -n "$name" ]]; then
            echo "$name|$file"
        fi
    done > "$temp_file"

    # Find and display duplicates
    if [[ -f "$temp_file" && -s "$temp_file" ]]; then
        # Get unique names that appear more than once
        cut -d'|' -f1 "$temp_file" | sort | uniq -d > "$dup_file"

        if [[ -s "$dup_file" ]]; then
            while read -r dup_name; do
                echo "⚠️ Duplicate name '$dup_name' found in:"
                grep "^${dup_name}|" "$temp_file" | cut -d'|' -f2 | while read -r file; do
                    echo "   - $file"
                done
            done < "$dup_file"
        else
            echo "✅ No duplicate agent names found"
        fi

        rm -f "$temp_file" "$dup_file"
    else
        echo "❌ No agents found to check"
    fi
}

# Export functions for use in other scripts
export -f count_agents
export -f search_agents_by_name
export -f validate_agent_file
export -f get_agent_name
export -f get_agent_description
export -f sample_agents
export -f list_agents_by_category
export -f find_agents_with_functionality
export -f search_agents_by_content
export -f get_agent_metadata
export -f list_all_agents_with_metadata
export -f find_agents_by_tag
export -f validate_all_agents
export -f create_agent_index
export -f search_agent_index
export -f get_agent_stats
export -f find_duplicate_agents