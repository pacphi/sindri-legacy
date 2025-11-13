#!/bin/bash
#
# clone-project.sh - Clone or fork repository with Claude enhancements
#
# Clones or forks an existing repository and applies Claude AI enhancements
# including Git hooks, dependency installation, CLAUDE.md creation, and
# Claude tool initialization.
#

# SECURITY: Enhanced error handling (H3 fix)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/git.sh"
source "${SCRIPT_DIR}/project-core.sh"
source "${SCRIPT_DIR}/project-helpers.sh"  # SECURITY: Input validation (H1 fix)

REPO_URL=""
FORK_MODE=false
BRANCH_NAME=""
CLONE_DEPTH=""
GIT_NAME=""
GIT_EMAIL=""
FEATURE_BRANCH=""
SKIP_DEPS=false
SKIP_ENHANCE=false
PROJECT_NAME=""

show_usage() {
    echo "Usage: $0 <repository-url> [options]"
    echo ""
    echo "Clone or fork a repository and enhance it with Claude tools"
    echo ""
    echo "Options:"
    echo "  --fork              Fork repo before cloning (requires gh CLI)"
    echo "  --branch <name>     Checkout specific branch after clone"
    echo "  --depth <n>         Shallow clone with n commits"
    echo "  --git-name <name>   Configure Git user name for this project"
    echo "  --git-email <email> Configure Git user email for this project"
    echo "  --feature <name>    Create and checkout feature branch after clone"
    echo "  --no-deps           Skip dependency installation"
    echo "  --no-enhance        Skip all enhancements (just clone/fork)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/user/my-app"
    echo "  $0 https://github.com/original/project --fork"
    echo "  $0 https://github.com/original/project --fork --feature add-new-feature"
    echo "  $0 https://github.com/company/app --git-name \"John Doe\""
    exit 1
}

if [ $# -eq 0 ]; then
    show_usage
fi

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
fi

REPO_URL="$1"

# SECURITY: Validate repository URL (H1 fix)
if ! validate_repo_url "$REPO_URL"; then
    print_error "Invalid repository URL"
    exit 1
fi

shift

PROJECT_NAME=$(basename "$REPO_URL" .git)
if [[ -z "$PROJECT_NAME" ]]; then
    print_error "Could not determine project name from URL"
    exit 1
fi

# SECURITY: Validate extracted project name (H1 fix)
if ! validate_project_name "$PROJECT_NAME"; then
    print_error "Invalid project name extracted from URL: $PROJECT_NAME"
    exit 1
fi

# SECURITY: Sanitize project path (H1 fix)
PROJECT_PATH=$(sanitize_project_path "/workspace/projects/active" "$PROJECT_NAME")
if [[ $? -ne 0 ]]; then
    print_error "Failed to create safe project path"
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --fork)
            # Fork repository before cloning (requires gh CLI)
            FORK_MODE=true
            shift
            ;;
        --branch)
            # Checkout specific branch after clone
            BRANCH_NAME="$2"
            shift 2
            ;;
        --depth)
            # Perform shallow clone with specified commit depth
            CLONE_DEPTH="$2"
            shift 2
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
        --feature)
            # Create and checkout feature branch after clone
            FEATURE_BRANCH="$2"
            shift 2
            ;;
        --no-deps)
            # Skip automatic dependency installation
            SKIP_DEPS=true
            shift
            ;;
        --no-enhance)
            # Skip all Claude enhancements (just clone/fork)
            SKIP_ENHANCE=true
            shift
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

PROJECT_DIR="$PROJECTS_DIR/active/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    print_error "Project $PROJECT_NAME already exists at $PROJECT_DIR"
    exit 1
fi

if [[ "$FORK_MODE" == true ]]; then
    if ! command_exists gh; then
        print_error "GitHub CLI (gh) is required for forking. Please install it first."
        exit 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        print_error "GitHub CLI is not authenticated. Please run: gh auth login"
        exit 1
    fi

    print_status "Forking repository: $REPO_URL"

    cd "$PROJECTS_DIR/active" || exit 1
    if ! gh repo fork "$REPO_URL" --clone; then
        print_error "Failed to fork repository"
        exit 1
    fi

    cd "$PROJECT_NAME" || exit 1

    if [[ "$SKIP_ENHANCE" != true ]]; then
        print_status "Setting up fork remotes and aliases..."
        setup_fork_remotes
        setup_fork_aliases
    fi
else
    print_status "Cloning repository: $REPO_URL"

    CLONE_CMD="git clone"
    if [[ -n "$CLONE_DEPTH" ]]; then
        CLONE_CMD="$CLONE_CMD --depth $CLONE_DEPTH"
    fi
    if [[ -n "$BRANCH_NAME" ]]; then
        CLONE_CMD="$CLONE_CMD --branch $BRANCH_NAME"
    fi
    CLONE_CMD="$CLONE_CMD \"$REPO_URL\" \"$PROJECT_DIR\""

    if ! eval "$CLONE_CMD"; then
        print_error "Failed to clone repository"
        exit 1
    fi

    cd "$PROJECT_DIR" || exit 1
fi

if [[ -n "$BRANCH_NAME" ]] && [[ "$FORK_MODE" == true ]]; then
    print_status "Checking out branch: $BRANCH_NAME"
    git checkout "$BRANCH_NAME" 2>/dev/null || {
        print_warning "Branch $BRANCH_NAME not found locally, trying to fetch from upstream"
        git fetch upstream "$BRANCH_NAME" 2>/dev/null && git checkout -b "$BRANCH_NAME" "upstream/$BRANCH_NAME"
    } || {
        print_error "Could not checkout branch: $BRANCH_NAME"
    }
fi

if [[ -n "$GIT_NAME" ]] || [[ -n "$GIT_EMAIL" ]]; then
    apply_git_config_overrides ${GIT_NAME:+--name "$GIT_NAME"} ${GIT_EMAIL:+--email "$GIT_EMAIL"} || exit 1
fi

if [[ "$SKIP_ENHANCE" != true ]]; then
    print_status "Applying Claude enhancements..."

    setup_git_hooks "$PROJECT_DIR"

    create_project_claude_md --from-cli || exit 1

    setup_project_enhancements \
        ${SKIP_DEPS:+--skip-deps} \
        ${GIT_NAME:+--git-name "$GIT_NAME"} \
        ${GIT_EMAIL:+--git-email "$GIT_EMAIL"} || exit 1
fi

if [[ -n "$FEATURE_BRANCH" ]]; then
    print_status "Creating feature branch: $FEATURE_BRANCH"
    git checkout -b "$FEATURE_BRANCH"
    print_success "Switched to new branch: $FEATURE_BRANCH"
fi

print_success "Project $PROJECT_NAME cloned successfully"
echo "📁 Location: $PROJECT_DIR"
echo "📝 Next steps:"
echo "   1. cd $PROJECT_DIR"
if [[ ! -f "CLAUDE.md" ]] || [[ "$SKIP_ENHANCE" == true ]]; then
    echo "   2. Run 'claude /init' to set up project context"
fi
echo "   3. Start coding with: claude"

echo ""
echo "Git Configuration:"
echo "   User: $(git config user.name) <$(git config user.email)>"
echo "   Branch: $(git branch --show-current)"
if [[ "$FORK_MODE" == true ]]; then
    echo "   Origin: $(git remote get-url origin 2>/dev/null || echo 'not set')"
    echo "   Upstream: $(git remote get-url upstream 2>/dev/null || echo 'not set')"
fi
