#!/bin/bash

# Script to upload AKC infrastructure to GitHub
# This script initializes git repo and pushes to GitHub

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# GitHub repository details
GITHUB_REPO="https://github.com/0xGuyG/k8s-akc.git"
REPO_NAME="k8s-akc"

echo "=================================================="
echo "🚀 Uploading AKC Infrastructure to GitHub"
echo "=================================================="
echo ""

# Check if we're in the right directory
if [ ! -f "setup.sh" ]; then
    log_error "setup.sh not found. Please run this script from the kubernetes-akc-infrastructure directory."
    exit 1
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    log_error "git is not installed. Please install git first."
    exit 1
fi

# Check if GitHub CLI is available (optional)
if command -v gh &> /dev/null; then
    GH_AVAILABLE=true
    log_info "GitHub CLI is available for enhanced functionality."
else
    GH_AVAILABLE=false
    log_warn "GitHub CLI not found. Using standard git commands."
fi

log_step "Initializing Git repository..."

# Initialize git repository if not already initialized
if [ ! -d ".git" ]; then
    git init
    log_info "Git repository initialized."
else
    log_info "Git repository already exists."
fi

log_step "Setting up Git configuration..."

# Set Git configuration (if not already set)
if [ -z "$(git config user.name 2>/dev/null)" ]; then
    read -p "Enter your Git username: " git_username
    git config user.name "$git_username"
fi

if [ -z "$(git config user.email 2>/dev/null)" ]; then
    read -p "Enter your Git email: " git_email
    git config user.email "$git_email"
fi

log_info "Git user: $(git config user.name) <$(git config user.email)>"

log_step "Adding files to Git..."

# Add all files to git
git add .

# Create initial commit
log_step "Creating initial commit..."

commit_message="Initial commit: Complete AKC Infrastructure

- Kubernetes cluster deployment with Calico CNI
- Alteon ADC integration with BGP peering
- AKC Controller and Aggregator Helm charts
- Comprehensive monitoring with Prometheus and Grafana
- Security configurations with RBAC and Pod Security Standards
- Sample applications and service examples
- CI/CD pipeline with GitLab integration
- One-click setup script for complete automation
- Comprehensive documentation and troubleshooting guides

Features:
✅ Production-ready Kubernetes cluster
✅ BGP integration with Alteon ADC
✅ VIP pool management
✅ SSL/TLS and WAF policy support
✅ Monitoring and alerting
✅ Security hardening
✅ Automated deployment
✅ Sample applications
✅ Troubleshooting tools

Ready for RHEL 9 deployment with complete automation."

git commit -m "$commit_message"

log_info "Initial commit created successfully."

log_step "Setting up remote repository..."

# Add remote origin
if git remote get-url origin &>/dev/null; then
    log_info "Remote origin already exists: $(git remote get-url origin)"
    read -p "Do you want to update the remote URL to $GITHUB_REPO? [y/N]: " update_remote
    if [[ "$update_remote" =~ ^[Yy]$ ]]; then
        git remote set-url origin "$GITHUB_REPO"
        log_info "Remote origin updated."
    fi
else
    git remote add origin "$GITHUB_REPO"
    log_info "Remote origin added: $GITHUB_REPO"
fi

log_step "Pushing to GitHub..."

# Push to GitHub
log_info "Pushing to GitHub repository..."

if git push -u origin main; then
    log_info "✅ Successfully pushed to GitHub!"
else
    log_warn "Push failed. Trying to push to 'master' branch..."
    if git push -u origin master; then
        log_info "✅ Successfully pushed to GitHub (master branch)!"
    else
        log_error "❌ Failed to push to GitHub. Please check your credentials and repository access."
        log_info "You may need to:"
        log_info "1. Ensure the repository exists on GitHub"
        log_info "2. Check your GitHub authentication"
        log_info "3. Verify repository permissions"
        exit 1
    fi
fi

echo ""
echo "=================================================="
echo "🎉 Upload Complete!"
echo "=================================================="
echo ""

log_info "📍 Repository URL: $GITHUB_REPO"
log_info "🌐 Web Interface: https://github.com/0xGuyG/k8s-akc"
log_info "📋 Clone Command: git clone $GITHUB_REPO"

echo ""
log_info "🚀 Quick Start Commands:"
echo "   git clone $GITHUB_REPO"
echo "   cd $REPO_NAME"
echo "   ./setup.sh"

echo ""
log_info "📚 Next Steps:"
log_info "1. Verify the repository on GitHub"
log_info "2. Update repository description and topics"
log_info "3. Configure branch protection rules"
log_info "4. Set up GitHub Actions (if needed)"
log_info "5. Add collaborators"

if [ "$GH_AVAILABLE" = true ]; then
    echo ""
    log_info "🔧 GitHub CLI Commands:"
    echo "   gh repo view 0xGuyG/k8s-akc"
    echo "   gh repo edit 0xGuyG/k8s-akc --description 'Complete Kubernetes AKC Infrastructure with One-Click Setup'"
    echo "   gh repo edit 0xGuyG/k8s-akc --add-topic kubernetes,alteon,akc,infrastructure,automation"
fi

echo ""
log_info "✨ Your AKC infrastructure is now available on GitHub!"
echo "   Users can now deploy with: curl -sSL https://raw.githubusercontent.com/0xGuyG/k8s-akc/main/setup.sh | bash"