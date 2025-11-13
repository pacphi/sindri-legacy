#!/bin/bash
# vm-setup.sh - Initial setup script for Sindri on Fly.io
# This script helps set up the Fly.io VM with all necessary tools and configurations

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables (can be overridden with environment variables)
APP_NAME="${APP_NAME:-sindri-dev-env}"
REGION="${REGION:-sjc}"
VM_MEMORY="${VM_MEMORY:-8192}"
CPU_KIND="${CPU_KIND:-shared}"
CPU_COUNT="${CPU_COUNT:-2}"
VOLUME_SIZE="${VOLUME_SIZE:-30}"
VOLUME_NAME="${VOLUME_NAME:-sindri_data}"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install flyctl
install_flyctl() {
    print_status "Installing Fly.io CLI..."

    # Download and run the official installer
    if curl -L https://fly.io/install.sh | sh; then
        print_success "Fly.io CLI installed successfully"

        # Add flyctl to PATH for current session
        export FLYCTL_INSTALL="$HOME/.fly"
        export PATH="$FLYCTL_INSTALL/bin:$PATH"

        # Verify installation
        if command_exists flyctl; then
            print_success "flyctl is now available in PATH"
            return 0
        else
            print_error "Installation succeeded but flyctl not found in PATH"
            print_status "You may need to restart your terminal or add ~/.fly/bin to your PATH"
            return 1
        fi
    else
        print_error "Failed to install Fly.io CLI"
        print_status "Please install manually from: https://fly.io/docs/getting-started/installing-flyctl/"
        return 1
    fi
}

# Function to check if flyctl is installed and authenticated
check_flyctl() {
    if ! command_exists flyctl; then
        print_error "Fly.io CLI (flyctl) is not installed."
        echo ""
        read -p "Would you like to install it now? (y/n) " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! install_flyctl; then
                exit 1
            fi
        else
            print_status "Please install flyctl manually from: https://fly.io/docs/getting-started/installing-flyctl/"
            exit 1
        fi
    fi

    # Check if authenticated
    if ! flyctl auth whoami >/dev/null 2>&1; then
        print_error "You are not authenticated with Fly.io."
        print_status "Please run: flyctl auth login"
        exit 1
    fi

    print_success "Fly.io CLI is installed and authenticated"
}

# Function to check for required files
check_required_files() {
    local missing_files=()

    if [[ ! -f "Dockerfile" ]]; then
        missing_files+=("Dockerfile")
    fi

    if [[ ! -f "fly.toml" ]]; then
        missing_files+=("fly.toml")
    fi

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "Missing required files: ${missing_files[*]}"
        print_status "Please ensure you have the following files in the current directory:"
        print_status "  - Dockerfile (container configuration)"
        print_status "  - fly.toml (Fly.io application configuration)"
        exit 1
    fi

    print_success "All required files found"
}

# Function to check SSH key
check_ssh_key() {
    local ssh_key_path="$HOME/.ssh/id_rsa.pub"
    local private_key_path="$HOME/.ssh/id_rsa"

    if [[ ! -f "$ssh_key_path" ]]; then
        print_warning "SSH public key not found at $ssh_key_path"
        print_status "Checking for other SSH keys..."

        # Look for other common SSH key names
        for key_type in id_ed25519 id_ecdsa id_dsa; do
            if [[ -f "$HOME/.ssh/${key_type}.pub" ]]; then
                ssh_key_path="$HOME/.ssh/${key_type}.pub"
                private_key_path="$HOME/.ssh/${key_type}"
                print_success "Found SSH key: $ssh_key_path"
                break
            fi
        done

        if [[ ! -f "$ssh_key_path" ]]; then
            print_error "No SSH public key found."
            print_status "Please generate an SSH key pair:"
            print_status "  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"
            print_status "  chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub"
            print_status "  OR"
            print_status "  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa"
            print_status "  chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub"
            exit 1
        fi
    fi

    # Validate SSH directory first
    if ! validate_ssh_directory; then
        print_error "SSH directory validation failed"
        exit 1
    fi

    # Validate SSH key permissions
    if ! validate_ssh_permissions "$private_key_path"; then
        print_error "SSH key permission validation failed"
        exit 1
    fi

    export SSH_KEY_PATH="$ssh_key_path"
    export PRIVATE_KEY_PATH="$private_key_path"
    print_success "SSH key found: $ssh_key_path"
}

# Function to validate and fix SSH key permissions
# SECURITY: Enhanced validation with error handling (C6 fix)
# Returns 0 on success, 1 on failure
validate_ssh_permissions() {
    local private_key="$1"
    local public_key="${private_key}.pub"

    print_status "Validating SSH key permissions..."

    # Check private key exists
    if [[ ! -f "$private_key" ]]; then
        print_error "Private key not found: $private_key"
        return 1
    fi

    # Check public key exists
    if [[ ! -f "$public_key" ]]; then
        print_error "Public key not found: $public_key"
        return 1
    fi

    # Attempt to fix private key permissions
    if ! chmod 600 "$private_key" 2>/dev/null; then
        print_error "Failed to set permissions on private key: $private_key"
        return 1
    fi

    # Verify private key permissions were set correctly
    local actual_perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        actual_perms=$(stat -f "%A" "$private_key" 2>/dev/null)
    else
        actual_perms=$(stat -c "%a" "$private_key" 2>/dev/null)
    fi

    if [[ -z "$actual_perms" ]]; then
        print_error "Failed to read permissions for: $private_key"
        return 1
    fi

    if [[ "$actual_perms" != "600" ]]; then
        print_error "Private key has incorrect permissions: $actual_perms (expected 600)"
        print_error "File: $private_key"
        return 1
    fi

    # Fix public key permissions (644 is acceptable for public keys)
    if ! chmod 644 "$public_key" 2>/dev/null; then
        print_error "Failed to set permissions on public key: $public_key"
        return 1
    fi

    # Verify public key permissions
    if [[ "$OSTYPE" == "darwin"* ]]; then
        actual_perms=$(stat -f "%A" "$public_key" 2>/dev/null)
    else
        actual_perms=$(stat -c "%a" "$public_key" 2>/dev/null)
    fi

    if [[ -z "$actual_perms" ]]; then
        print_error "Failed to read permissions for: $public_key"
        return 1
    fi

    if [[ "$actual_perms" != "644" ]]; then
        print_warning "Public key has unusual permissions: $actual_perms (expected 644)"
    fi

    # Verify key is valid SSH key format
    if ! ssh-keygen -l -f "$private_key" >/dev/null 2>&1; then
        print_error "Private key is not a valid SSH key: $private_key"
        return 1
    fi

    if ! ssh-keygen -l -f "$public_key" >/dev/null 2>&1; then
        print_error "Public key is not a valid SSH key: $public_key"
        return 1
    fi

    print_success "SSH key permissions validated: $private_key"
    return 0
}

# Function to validate SSH directory permissions
# SECURITY: Additional validation for ~/.ssh directory (C6 fix)
# Returns 0 on success, 1 on failure
validate_ssh_directory() {
    local ssh_dir="$HOME/.ssh"

    print_status "Validating SSH directory permissions..."

    # Create directory if it doesn't exist
    if [[ ! -d "$ssh_dir" ]]; then
        if ! mkdir -p "$ssh_dir" 2>/dev/null; then
            print_error "Failed to create SSH directory: $ssh_dir"
            return 1
        fi
    fi

    # Set directory permissions
    if ! chmod 700 "$ssh_dir" 2>/dev/null; then
        print_error "Failed to set permissions on SSH directory: $ssh_dir"
        return 1
    fi

    # Verify directory permissions
    local actual_perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        actual_perms=$(stat -f "%A" "$ssh_dir" 2>/dev/null)
    else
        actual_perms=$(stat -c "%a" "$ssh_dir" 2>/dev/null)
    fi

    if [[ -z "$actual_perms" ]]; then
        print_error "Failed to read permissions for: $ssh_dir"
        return 1
    fi

    if [[ "$actual_perms" != "700" ]]; then
        print_error "SSH directory has incorrect permissions: $actual_perms (expected 700)"
        return 1
    fi

    print_success "SSH directory permissions validated"
    return 0
}

# Function to create Fly.io application
create_fly_app() {
    print_status "Creating Fly.io application: $APP_NAME"

    # Check if app already exists
    if flyctl apps list | grep -q "^$APP_NAME"; then
        print_warning "Application $APP_NAME already exists"
        read -p "Do you want to continue with the existing app? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Exiting. Please choose a different APP_NAME or delete the existing app."
            exit 1
        fi
    else
        # Create new app
        flyctl apps create "$APP_NAME" --org personal
        print_success "Created application: $APP_NAME"
    fi
}

# Function to create persistent volume
create_volume() {
    print_status "Creating persistent volume: $VOLUME_NAME"

    # Check if volume already exists
    if flyctl volumes list -a "$APP_NAME" | grep -q "$VOLUME_NAME"; then
        print_warning "Volume $VOLUME_NAME already exists"
        flyctl volumes list -a "$APP_NAME"
        read -p "Do you want to continue with the existing volume? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Exiting. Please choose a different VOLUME_NAME or delete the existing volume."
            exit 1
        fi
    else
        # Create new volume
        flyctl volumes create "$VOLUME_NAME" \
            --app "$APP_NAME" \
            --region "$REGION" \
            --size "$VOLUME_SIZE" \
            --no-encryption \
            --yes
        print_success "Created volume: $VOLUME_NAME ($VOLUME_SIZE GB)"
    fi
}

# Function to configure secrets
configure_secrets() {
    print_status "Configuring SSH keys and secrets"

    # Set SSH authorized keys
    local ssh_key_content
    ssh_key_content=$(cat "$SSH_KEY_PATH")
    flyctl secrets set AUTHORIZED_KEYS="$ssh_key_content" -a "$APP_NAME"
    print_success "SSH keys configured"

    # Optionally set Anthropic API key
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        flyctl secrets set ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" -a "$APP_NAME"
        print_success "Anthropic API key configured"
    else
        print_warning "ANTHROPIC_API_KEY not set. You can set it later with:"
        print_warning "  flyctl secrets set ANTHROPIC_API_KEY=your_api_key -a $APP_NAME"
    fi

    # Optionally set GitHub credentials
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        print_status "Setting GitHub token..."
        flyctl secrets set GITHUB_TOKEN="$GITHUB_TOKEN" -a "$APP_NAME"
        print_success "GitHub token configured"
    else
        print_status "No GITHUB_TOKEN found. You can set it later with:"
        print_status "  flyctl secrets set GITHUB_TOKEN=<your-token> -a $APP_NAME"
    fi

    if [[ -n "${GIT_USER_NAME:-}" ]]; then
        flyctl secrets set GIT_USER_NAME="$GIT_USER_NAME" -a "$APP_NAME"
        print_success "Git user name configured: $GIT_USER_NAME"
    fi

    if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
        flyctl secrets set GIT_USER_EMAIL="$GIT_USER_EMAIL" -a "$APP_NAME"
        print_success "Git user email configured: $GIT_USER_EMAIL"
    fi

    if [[ -n "${GITHUB_USER:-}" ]]; then
        flyctl secrets set GITHUB_USER="$GITHUB_USER" -a "$APP_NAME"
        print_success "GitHub username configured: $GITHUB_USER"
    fi

    # Optionally set Perplexity API key for Goalie
    if [[ -n "${PERPLEXITY_API_KEY:-}" ]]; then
        flyctl secrets set PERPLEXITY_API_KEY="$PERPLEXITY_API_KEY" -a "$APP_NAME"
        print_success "Perplexity API key configured"
    else
        print_status "No PERPLEXITY_API_KEY found. You can set it later with:"
        print_status "  flyctl secrets set PERPLEXITY_API_KEY=<your-key> -a $APP_NAME"
        print_status "  Get your API key from: https://www.perplexity.ai/settings/api"
    fi
}

# Function to update fly.toml with correct app name
update_fly_toml() {
    print_status "Updating fly.toml with app name and configuration"

    # Use the configuration script to prepare fly.toml
    export APP_NAME
    export REGION
    export SSH_EXTERNAL_PORT="10022"
    export CPU_KIND
    export CPU_COUNT
    export VM_MEMORY
    export VOLUME_SIZE
    ./scripts/prepare-fly-config.sh

    print_success "fly.toml updated"
}

# Function to deploy application
deploy_app() {
    print_status "Deploying application to Fly.io"

    # Deploy the application
    flyctl deploy --app "$APP_NAME" --yes

    print_success "Application deployed successfully"
}

# Function to show connection information
show_connection_info() {
    print_success "Setup complete! Here's how to connect:"
    echo
    print_status "SSH Connection:"
    echo "  ssh developer@$APP_NAME.fly.dev -p 10022"
    echo
    print_status "SSH Config Entry (add to ~/.ssh/config):"
    echo "  Host $APP_NAME"
    echo "      HostName $APP_NAME.fly.dev"
    echo "      Port 10022"
    echo "      User developer"
    echo "      IdentityFile $PRIVATE_KEY_PATH  # IMPORTANT: Use private key (no .pub)"
    echo "      ServerAliveInterval 60"
    echo "      ServerAliveCountMax 3"
    echo
    print_warning "⚠️  SSH Config Important Notes:"
    echo "  • IdentityFile should point to your PRIVATE key ($PRIVATE_KEY_PATH)"
    echo "  • Do NOT use the .pub file in IdentityFile (common mistake)"
    echo "  • Test connection: ssh $APP_NAME"
    echo
    print_status "Useful Commands:"
    echo "  flyctl status -a $APP_NAME        # Check app status"
    echo "  flyctl logs -a $APP_NAME          # View logs"
    echo "  flyctl ssh console -a $APP_NAME   # Direct SSH access"
    echo "  flyctl machine list -a $APP_NAME  # List machines"
    echo "  flyctl volumes list -a $APP_NAME  # List volumes"
    echo
    print_status "Next Steps:"
    echo "  1. Connect via SSH or IDE remote development"
    echo "  2. Configure extensions: extension-manager --interactive"
    echo "  3. Authenticate Claude Code: claude"
    echo "  4. Start developing!"
}

# Function to show cost information
show_cost_info() {
    echo
    # Calculate actual costs based on configuration
    source "$SCRIPT_DIR/lib/fly-common.sh" 2>/dev/null || true
    local hourly_cost=$(calculate_hourly_cost "$CPU_KIND" "$CPU_COUNT" "$VM_MEMORY" 2>/dev/null || echo "0.0067")
    local monthly_compute=$(echo "scale=2; $hourly_cost * 720" | bc 2>/dev/null || echo "5")
    local volume_cost=$(echo "scale=2; $VOLUME_SIZE * 0.15" | bc 2>/dev/null || echo "1.50")
    local estimated_total=$(echo "scale=2; ($hourly_cost * 360) + $volume_cost" | bc 2>/dev/null || echo "5")

    print_status "💰 Cost Information:"
    echo "  • VM (when running): \$$hourly_cost/hr or \$$monthly_compute/mo if always on"
    echo "  • Volume ($VOLUME_SIZE GB): \$$volume_cost/mo"
    echo "  • Estimated total (50% uptime): ~\$$estimated_total/mo"
    echo "  • Scale to zero: Only pay for storage (\$$volume_cost/mo) when idle"
    echo
    print_warning "💡 Volume costs persist even when VM is stopped!"
}

# Main execution function
main() {
    echo "🚀 Setting up Sindri on Fly.io"
    echo "=================================================="
    echo

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-name)
                APP_NAME="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --volume-size)
                VOLUME_SIZE="$2"
                shift 2
                ;;
            --memory)
                VM_MEMORY="$2"
                shift 2
                ;;
            --cpu-kind)
                CPU_KIND="$2"
                shift 2
                ;;
            --cpu-count)
                CPU_COUNT="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --app-name NAME     Name for the Fly.io app (default: sindri-dev-env)
  --region REGION     Fly.io region (default: sjc)
  --volume-size SIZE  Volume size in GB (default: 30)
  --memory SIZE       VM memory in MB (default: 8192)
  --cpu-kind KIND     CPU type: "shared" or "performance" (default: shared)
  --cpu-count COUNT   Number of CPUs (default: 2)
  --help              Show this help message

Environment Variables:
  ANTHROPIC_API_KEY   Your Anthropic API key (optional)
  GITHUB_TOKEN        GitHub personal access token for authentication (optional)
  GIT_USER_NAME       Git config user.name (optional)
  GIT_USER_EMAIL      Git config user.email (optional)
  GITHUB_USER         GitHub username for gh CLI (optional)
  PERPLEXITY_API_KEY  Perplexity API key for Goalie research assistant (optional)

Examples:
  $0
  $0 --app-name my-dev --region sjc --volume-size 20
  $0 --cpu-kind performance --cpu-count 2 --memory 2048
  ANTHROPIC_API_KEY=sk-ant-... $0 --app-name claude-dev
  GITHUB_TOKEN=ghp_... GIT_USER_NAME="John Doe" GIT_USER_EMAIL="john@example.com" $0
  PERPLEXITY_API_KEY=pplx-... $0 --app-name claude-dev

EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_status "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    print_status "Configuration:"
    echo "  App Name: $APP_NAME"
    echo "  Region: $REGION"
    echo "  Volume Size: ${VOLUME_SIZE}GB"
    echo "  VM Memory: ${VM_MEMORY}MB"
    echo "  CPU Kind: $CPU_KIND"
    echo "  CPU Count: $CPU_COUNT"
    echo

    # Confirm before proceeding
    read -p "Continue with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Setup cancelled"
        exit 0
    fi

    # Run setup steps
    check_flyctl
    check_required_files
    check_ssh_key
    update_fly_toml
    create_fly_app
    create_volume
    configure_secrets
    deploy_app

    # Show connection information
    show_connection_info
    show_cost_info

    print_success "🎉 Setup complete! Your Sindri development environment is ready."
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi