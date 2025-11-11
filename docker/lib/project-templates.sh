#!/bin/bash
#
# project-templates.sh - Template loading, validation, and processing
#
# This library provides functions for loading project templates from YAML,
# validating them against JSON Schema, and processing template variables.
# Uses yq for reliable YAML parsing instead of awk.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TEMPLATES_CONFIG="${TEMPLATES_CONFIG:-${SCRIPT_DIR}/project-templates.yaml}"
TEMPLATES_SCHEMA="${TEMPLATES_SCHEMA:-${SCRIPT_DIR}/project-templates.schema.json}"

_check_yq() {
    if ! command_exists yq; then
        print_error "yq is required for template processing"
        print_error "Install: brew install yq (macOS) or sudo apt install yq (Linux)"
        return 1
    fi
    return 0
}

get_template_types() {
    _check_yq || return 1

    if [[ ! -f "$TEMPLATES_CONFIG" ]]; then
        print_error "Templates config not found: $TEMPLATES_CONFIG"
        return 1
    fi

    yq eval '.templates | keys | .[]' "$TEMPLATES_CONFIG"
}

get_template_description() {
    local template_type="$1"
    _check_yq || return 1

    yq eval ".templates.${template_type}.description // \"\"" "$TEMPLATES_CONFIG"
}

load_project_template() {
    local template_type="$1"
    _check_yq || return 1

    if [[ ! -f "$TEMPLATES_CONFIG" ]]; then
        print_error "Templates config not found: $TEMPLATES_CONFIG"
        return 1
    fi

    local template
    template=$(yq eval ".templates.${template_type} // null" -o=json "$TEMPLATES_CONFIG")

    if [[ "$template" == "null" ]]; then
        print_error "Template not found: $template_type"
        return 1
    fi

    echo "$template"
}

validate_template_schema() {
    if [[ ! -f "$TEMPLATES_SCHEMA" ]]; then
        print_debug "Schema file not found: $TEMPLATES_SCHEMA (skipping validation)"
        return 0
    fi

    if ! command_exists ajv; then
        print_debug "ajv-cli not available (skipping schema validation)"
        return 0
    fi

    print_status "Validating template schema..."

    if ajv validate -s "$TEMPLATES_SCHEMA" -d "$TEMPLATES_CONFIG" 2>/dev/null; then
        print_success "Template schema validation passed"
        return 0
    else
        print_error "Template schema validation failed"
        return 1
    fi
}

resolve_template_variables() {
    local content="$1"
    local variables_json="$2"

    local result="$content"

    while IFS= read -r key; do
        local value
        value=$(echo "$variables_json" | yq eval ".${key}" -)
        result=$(echo "$result" | sed "s|{${key}}|${value}|g")
    done < <(echo "$variables_json" | yq eval 'keys | .[]' -)

    echo "$result"
}

execute_template_setup() {
    local template_json="$1"
    local variables_json="$2"

    print_status "Executing setup commands..."

    local commands
    commands=$(echo "$template_json" | yq eval '.setup_commands // [] | .[]' -)

    if [[ -z "$commands" ]]; then
        print_debug "No setup commands to execute"
        return 0
    fi

    while IFS= read -r cmd; do
        if [[ -n "$cmd" ]]; then
            cmd=$(resolve_template_variables "$cmd" "$variables_json")

            print_debug "Running: $cmd"
            if eval "$cmd" 2>/dev/null; then
                print_debug "Command succeeded: $cmd"
            else
                print_warning "Command failed: $cmd"
            fi
        fi
    done <<< "$commands"

    return 0
}

create_template_files() {
    local template_json="$1"
    local variables_json="$2"

    print_status "Creating template files..."

    local files_json
    files_json=$(echo "$template_json" | yq eval '.files // {}' -o=json -)

    if [[ "$files_json" == "{}" ]]; then
        print_debug "No template files to create"
        return 0
    fi

    while IFS= read -r filepath; do
        if [[ -z "$filepath" ]]; then
            continue
        fi

        filepath=$(resolve_template_variables "$filepath" "$variables_json")

        local content
        content=$(echo "$template_json" | yq eval ".files.\"${filepath}\"" -)

        content=$(resolve_template_variables "$content" "$variables_json")

        mkdir -p "$(dirname "$filepath")"

        echo "$content" > "$filepath"
        print_debug "Created file: $filepath"
    done < <(echo "$template_json" | yq eval '.files | keys | .[]' -)

    print_success "Template files created"
    return 0
}

export -f get_template_types
export -f get_template_description
export -f load_project_template
export -f validate_template_schema
export -f resolve_template_variables
export -f execute_template_setup
export -f create_template_files
