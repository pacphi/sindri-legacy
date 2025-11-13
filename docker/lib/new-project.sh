#!/bin/bash
#
# new-project.sh - Create new project from template
#
# Creates a new project directory with intelligent type detection, template-based
# structure, extension activation via extension-manager, and Claude AI enhancements.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/git.sh"
source "${SCRIPT_DIR}/project-core.sh"
source "${SCRIPT_DIR}/project-templates.sh"
source "${SCRIPT_DIR}/project-helpers.sh"  # SECURITY: Input validation (H1 fix)

TEMPLATES_CONFIG="${SCRIPT_DIR}/project-templates.yaml"
PROJECT_NAME=""
PROJECT_TYPE=""
AUTO_DETECT=true
GIT_NAME=""
GIT_EMAIL=""
INTERACTIVE=false

show_usage() {
    echo "Usage: $0 <project_name> [options]"
    echo ""
    echo "Options:"
    echo "  --type <type>              Specify project type explicitly"
    echo "  --list-types               Show all available project types"
    echo "  --interactive              Force interactive type selection"
    echo "  --git-name <name>          Git user name for this project"
    echo "  --git-email <email>        Git user email for this project"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 my-rails-app            # Auto-detects Rails"
    echo "  $0 api-server              # Prompts for API type"
    echo "  $0 my-app --type python"
    echo "  $0 my-app --type spring --git-name \"John Doe\""

    if [[ -f "$TEMPLATES_CONFIG" ]]; then
        echo ""
        echo "Available Types:"
        get_template_types | pr -t -4
    fi
    exit 1
}

list_types() {
    echo "Available Project Types:"
    echo ""

    if [[ -f "$TEMPLATES_CONFIG" ]]; then
        local types
        mapfile -t types < <(get_template_types)
        for type in "${types[@]}"; do
            local desc
            desc=$(get_template_description "$type")
            printf "  %-12s %s\n" "$type" "$desc"
        done
    fi
    exit 0
}

detect_project_type() {
    local project_name="$1"
    local name_lower
    name_lower=$(echo "$project_name" | tr '[:upper:]' '[:lower:]')

    case "$name_lower" in
        *rails*) echo "rails" ;;                           # Ruby on Rails project
        *django*) echo "django" ;;                         # Django web application
        *spring*) echo "spring" ;;                         # Spring Boot application
        *terraform*|*tf*|*infra*) echo "terraform" ;;     # Infrastructure as code
        *docker*|*container*) echo "docker" ;;            # Dockerized application
        *api*|*service*) echo "api" ;;                    # API project (requires interactive selection)
        *web*|*frontend*|*ui*) echo "web" ;;              # Web project (requires interactive selection)
        *) echo "" ;;                                      # No pattern matched
    esac
}

select_project_type() {
    local detected="$1"
    local available_types
    mapfile -t available_types < <(get_template_types)

    if [[ "$detected" == "api" ]]; then
        print_status "Detected API project. What kind of API?"
        echo "Common choices for APIs:"
        echo "  1) node     - Node.js/Express API"
        echo "  2) python   - Python/FastAPI or Django REST"
        echo "  3) go       - Go API server"
        echo "  4) spring   - Spring Boot API"
        echo "  5) dotnet   - .NET Web API"
        echo ""
        read -r -p "Enter choice (1-5) or type name: " choice

        case "$choice" in
            1) echo "node" ;;      # Node.js/Express API
            2) echo "python" ;;    # Python/FastAPI or Django REST
            3) echo "go" ;;        # Go API server
            4) echo "spring" ;;    # Spring Boot API
            5) echo "dotnet" ;;    # .NET Web API
            *) echo "$choice" ;;   # User typed a custom name
        esac
    elif [[ "$detected" == "web" ]]; then
        print_status "Detected web project. What framework?"
        echo "Common choices for web apps:"
        echo "  1) node     - Node.js/Express"
        echo "  2) rails    - Ruby on Rails"
        echo "  3) django   - Django"
        echo "  4) dotnet   - ASP.NET Core"
        echo ""
        read -r -p "Enter choice (1-4) or type name: " choice

        case "$choice" in
            1) echo "node" ;;      # Node.js/Express
            2) echo "rails" ;;     # Ruby on Rails
            3) echo "django" ;;    # Django
            4) echo "dotnet" ;;    # ASP.NET Core
            *) echo "$choice" ;;   # User typed a custom name
        esac
    else
        print_status "Available project types:"
        printf "%s\n" "${available_types[@]}" | pr -t -3
        echo ""
        read -r -p "Enter project type [default: node]: " input
        echo "${input:-node}"
    fi
}

collect_template_variables() {
    local project_name="$1"

    local vars_json="{}"
    vars_json=$(echo "$vars_json" | yq eval ".project_name = \"$project_name\"" -)
    vars_json=$(echo "$vars_json" | yq eval ".author = \"$(git config user.name 2>/dev/null || echo '')\"" -)
    vars_json=$(echo "$vars_json" | yq eval ".git_user_name = \"$(git config user.name 2>/dev/null || echo '')\"" -)
    vars_json=$(echo "$vars_json" | yq eval ".git_user_email = \"$(git config user.email 2>/dev/null || echo '')\"" -)
    vars_json=$(echo "$vars_json" | yq eval ".date = \"$(date +%Y-%m-%d)\"" -)
    vars_json=$(echo "$vars_json" | yq eval ".year = \"$(date +%Y)\"" -)
    vars_json=$(echo "$vars_json" | yq eval ".description = \"Project description\"" -)
    vars_json=$(echo "$vars_json" | yq eval ".license = \"MIT\"" -)

    echo "$vars_json"
}

activate_extensions() {
    local template_json="$1"

    print_status "Activating extensions..."

    local extensions
    extensions=$(echo "$template_json" | yq eval '.extensions // [] | .[]' -)

    if [[ -z "$extensions" ]]; then
        print_debug "No extensions to activate"
        return 0
    fi

    while IFS= read -r ext; do
        if [[ -n "$ext" ]]; then
            print_status "Activating extension: $ext"
            if command_exists extension-manager; then
                if extension-manager install "$ext" 2>/dev/null; then
                    print_success "Extension activated: $ext"
                else
                    print_warning "Failed to activate extension: $ext"
                fi
            else
                print_warning "extension-manager not available, skipping: $ext"
            fi
        fi
    done <<< "$extensions"

    return 0
}

if [ $# -eq 0 ]; then
    show_usage
fi

case "$1" in
    --list-types)
        list_types
        ;;
    -h|--help)
        show_usage
        ;;
esac

PROJECT_NAME="$1"

# SECURITY: Validate project name (H1 fix)
if ! validate_project_name "$PROJECT_NAME"; then
    print_error "Invalid project name"
    exit 1
fi

shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            # Explicitly set project type and disable auto-detection
            PROJECT_TYPE="$2"
            AUTO_DETECT=false
            shift 2
            ;;
        --interactive)
            # Force interactive type selection even if type is detected
            INTERACTIVE=true
            shift
            ;;
        --list-types)
            # Display all available project types and exit
            list_types
            ;;
        --git-name)
            # Override git user.name for this project
            GIT_NAME="$2"
            shift 2
            ;;
        --git-email)
            # Override git user.email for this project
            GIT_EMAIL="$2"
            shift 2
            ;;
        -h|--help)
            # Display usage information and exit
            show_usage
            ;;
        *)
            # Unknown option provided
            print_error "Unknown option: $1"
            show_usage
            ;;
    esac
done

if [[ "$AUTO_DETECT" == "true" ]] && [[ -z "$PROJECT_TYPE" ]]; then
    DETECTED_TYPE=$(detect_project_type "$PROJECT_NAME")

    if [[ -n "$DETECTED_TYPE" ]] && [[ "$DETECTED_TYPE" != "api" ]] && [[ "$DETECTED_TYPE" != "web" ]] && [[ "$INTERACTIVE" != "true" ]]; then
        PROJECT_TYPE="$DETECTED_TYPE"
        print_status "Auto-detected project type: $PROJECT_TYPE"
    else
        PROJECT_TYPE=$(select_project_type "$DETECTED_TYPE")
    fi
fi

if [[ -z "$PROJECT_TYPE" ]]; then
    PROJECT_TYPE="node"
fi

if [[ -f "$TEMPLATES_CONFIG" ]]; then
    if ! get_template_types | grep -q "^${PROJECT_TYPE}$"; then
        print_warning "Unknown project type: $PROJECT_TYPE"
        print_status "Available types: $(get_template_types | tr '\n' ' ')"
        PROJECT_TYPE=$(select_project_type "")
    fi
fi

PROJECT_DIR="${PROJECTS_DIR:-/workspace/projects}/active/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    print_error "Project $PROJECT_NAME already exists"
    exit 1
fi

print_status "Creating new $PROJECT_TYPE project: $PROJECT_NAME"

print_status "Loading template: $PROJECT_TYPE"
template_json=$(load_project_template "$PROJECT_TYPE") || exit 1

activate_extensions "$template_json"

create_directory "$PROJECT_DIR" || exit 1
cd "$PROJECT_DIR" || exit 1

init_git_repo "$PROJECT_DIR" "$PROJECT_TYPE" || exit 1

if [[ -n "$GIT_NAME" ]] || [[ -n "$GIT_EMAIL" ]]; then
    apply_git_config_overrides ${GIT_NAME:+--name "$GIT_NAME"} ${GIT_EMAIL:+--email "$GIT_EMAIL"} || exit 1
fi

variables_json=$(collect_template_variables "$PROJECT_NAME")
execute_template_setup "$template_json" "$variables_json" || exit 1
create_template_files "$template_json" "$variables_json" || exit 1

claude_template=$(echo "$template_json" | yq eval '.claude_md_template // ""' -)
if [[ -n "$claude_template" ]]; then
    claude_template=$(resolve_template_variables "$claude_template" "$variables_json")
    create_project_claude_md --template "$claude_template" || exit 1
else
    create_project_claude_md || exit 1
fi

git add .
git commit -m "feat: initial project setup for $PROJECT_NAME"

setup_project_enhancements ${GIT_NAME:+--git-name "$GIT_NAME"} ${GIT_EMAIL:+--git-email "$GIT_EMAIL"} || exit 1

print_success "Project $PROJECT_NAME created successfully"
echo "📁 Location: $PROJECT_DIR"
echo "📝 Next steps:"
echo "   1. cd $PROJECT_DIR"
echo "   2. Edit CLAUDE.md with project details"
echo "   3. Start coding with: claude"
echo ""
echo "Git Configuration:"
echo "   User: $(git config user.name) <$(git config user.email)>"
echo "   Branch: $(git branch --show-current)"
