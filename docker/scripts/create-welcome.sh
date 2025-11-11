#!/bin/bash
set -e

# Create a welcome script for the developer user
# Create welcome script in /etc/skel so it gets copied to the persistent home
cat > /etc/skel/welcome.sh << 'EOF'
#!/bin/bash
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Welcome to Sindri - Your AI-Powered Development Forge!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 You are connected to: $(hostname)"
echo "💾 Workspace: /workspace"
echo "🔧 Available tools:"
echo "  - Git:"
git --version 2>/dev/null | sed 's/^/    /' || echo "    not installed"
echo "  - GitHub CLI:"
gh version 2>/dev/null | head -n1 | sed 's/^/    /' || echo "    not installed or not configured"
echo "  - jq:"
jq --version 2>/dev/null | sed 's/^/    /' || echo "    not installed"

echo ""
echo "📚 Next steps:"
echo "  1. Install development tools (optional):"
echo "     • Interactive setup: extension-manager --interactive"
echo "     • Install all active: extension-manager install-all"
echo "     • View available: extension-manager list"
echo "  2. Authenticate Claude Code: claude"
echo ""
echo "💡 Tip: Core tools (Claude Code, mise, Git) are pre-installed!"
echo ""
echo "💡 Tip: All your work should be in /workspace (persistent volume)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
EOF

chmod +x /etc/skel/welcome.sh