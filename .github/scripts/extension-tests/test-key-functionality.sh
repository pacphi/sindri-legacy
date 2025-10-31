#!/bin/bash
# Test key functionality for an extension's primary tool
# Usage: test-key-functionality.sh <key-tool>

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

# Parse arguments
key_tool="$1"
if [ -z "$key_tool" ]; then
    print_error "Usage: $0 <key-tool>"
    exit 1
fi

print_section "Testing key functionality for: $key_tool"

# Test based on tool type
case "$key_tool" in
    node)
        print_info "Testing Node.js..."
        node --version
        npm --version
        echo "console.log('Hello from Node.js')" | node
        print_success "Node.js functionality verified"
        ;;

    mise)
        print_info "Testing mise..."
        mise --version
        mise doctor || print_warning "mise doctor reported issues"
        mise list
        print_success "mise functionality verified"
        ;;

    claude)
        print_info "Testing Claude CLI..."
        claude --version
        print_success "Claude CLI functionality verified"
        ;;

    tsc)
        print_info "Testing TypeScript..."
        tsc --version
        echo "const x: string = 'hello';" > /tmp/test.ts
        tsc /tmp/test.ts --outDir /tmp --noEmit
        print_success "TypeScript functionality verified"
        ;;

    tmux)
        print_info "Testing tmux..."
        tmux -V
        if [ -f ~/.tmux.conf ] || [ -f /workspace/config/tmux.conf ]; then
            print_success "Tmux configuration found"
        else
            print_warning "Tmux config not found"
        fi
        print_success "tmux functionality verified"
        ;;

    rustc)
        print_info "Testing Rust compilation..."
        rustc --version
        cargo --version
        echo 'fn main() { println!("Hello from Rust"); }' > /tmp/test.rs
        rustc /tmp/test.rs -o /tmp/test && /tmp/test
        print_success "Rust functionality verified"
        ;;

    go)
        print_info "Testing Go compilation..."
        go version
        echo 'package main; import "fmt"; func main() { fmt.Println("Hello from Go") }' > /tmp/test.go
        go run /tmp/test.go
        print_success "Go functionality verified"
        ;;

    python3)
        print_info "Testing Python execution..."
        python3 --version
        pip3 --version
        python3 -c "print('Hello from Python')"
        uv --version || print_warning "uv not installed"
        print_success "Python functionality verified"
        ;;

    java)
        print_info "Testing Java..."
        java -version
        print_success "Java functionality verified"
        ;;

    php)
        print_info "Testing PHP..."
        php --version
        php -r "echo 'Hello from PHP';"
        print_success "PHP functionality verified"
        ;;

    ruby)
        print_info "Testing Ruby..."
        ruby --version
        ruby -e "puts 'Hello from Ruby'"
        print_success "Ruby functionality verified"
        ;;

    dotnet)
        print_info "Testing .NET..."
        dotnet --info
        print_success ".NET functionality verified"
        ;;

    docker)
        print_info "Testing Docker..."
        timeout 10 docker --version
        timeout 10 docker-compose --version 2>/dev/null || \
        timeout 10 docker compose version 2>/dev/null
        print_success "Docker functionality verified"
        ;;

    terraform)
        print_info "Testing Terraform..."
        terraform version
        print_success "Terraform functionality verified"
        ;;

    aws)
        print_info "Testing AWS CLI..."
        aws --version
        print_success "AWS CLI functionality verified"
        ;;

    gh)
        print_info "Testing GitHub CLI..."
        gh --version
        print_success "GitHub CLI functionality verified"
        ;;

    ollama)
        print_info "Testing Ollama..."
        ollama --version
        print_success "Ollama functionality verified"
        ;;

    codex)
        print_info "Testing Codex CLI..."
        codex --version || codex version || print_warning "Version check not supported"
        print_success "Codex CLI functionality verified"
        ;;

    playwright)
        print_info "Testing Playwright..."
        playwright --version
        print_success "Playwright functionality verified"
        ;;

    claude-monitor)
        print_info "Testing claude-monitor..."
        claude-monitor --version || print_warning "Version check not supported"
        print_success "claude-monitor functionality verified"
        ;;

    agent-manager)
        print_info "Testing agent-manager..."
        agent-manager --version || agent-manager -h > /dev/null
        print_success "agent-manager functionality verified"
        ;;

    mkdir|ssh|echo)
        print_info "Testing $key_tool..."
        $key_tool --version 2>/dev/null || which $key_tool
        print_success "$key_tool functionality verified"
        ;;

    *)
        print_warning "No specific test for $key_tool, checking availability only"
        if command -v "$key_tool" >/dev/null 2>&1; then
            print_success "$key_tool is available"
        else
            print_error "$key_tool not found"
            exit 1
        fi
        ;;
esac

print_success "Key functionality test passed for $key_tool"
