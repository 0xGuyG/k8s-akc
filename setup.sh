#!/bin/bash

# AKC Infrastructure Complete Setup Script
# This script sets up everything from prerequisites to full deployment
# Usage: curl -sSL https://raw.githubusercontent.com/your-repo/kubernetes-akc-infrastructure/main/setup.sh | bash

set -e

# Script configuration
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/akc-setup.log"
SETUP_DIR="/opt/akc-infrastructure"
USER_HOME="$HOME"

# Default configuration - can be overridden by environment variables
DEFAULT_CLUSTER_NAME="akc-cluster"
DEFAULT_NODE_COUNT="2"
DEFAULT_ALTEON_IP="10.0.0.100"
DEFAULT_VIP_POOL_START="10.0.1.10"
DEFAULT_VIP_POOL_END="10.0.1.100"
DEFAULT_BGP_AS_CALICO="65000"
DEFAULT_BGP_AS_ALTEON="65001"

# Repository configuration
REPO_URL="${REPO_URL:-https://github.com/0xGuyG/k8s-akc.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    log "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

log_debug() {
    log "${BLUE}[DEBUG]${NC} $1"
}

log_step() {
    log "${PURPLE}[STEP]${NC} $1"
}

log_progress() {
    log "${CYAN}[PROGRESS]${NC} $1"
}

# Function to display script banner
show_banner() {
    clear
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║           🚀 AKC Infrastructure Complete Setup Script 🚀                     ║
║                                                                              ║
║  This script will set up a complete Kubernetes cluster with Alteon AKC      ║
║  integration, including all prerequisites, monitoring, and sample apps.     ║
║                                                                              ║
║  • Kubernetes cluster with Calico CNI                                       ║
║  • Alteon ADC integration with BGP                                          ║
║  • AKC Controller and Aggregator                                            ║
║  • Prometheus and Grafana monitoring                                        ║
║  • Security policies and RBAC                                               ║
║  • Sample applications                                                       ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo ""
    log_info "Version: $SCRIPT_VERSION"
    log_info "Log file: $LOG_FILE"
    echo ""
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]] && [[ "$ALLOW_ROOT" != "true" ]]; then
        log_error "This script should not be run as root for security reasons."
        log_info "If you must run as root, set ALLOW_ROOT=true"
        log_info "Recommended: Run as regular user with sudo access"
        exit 1
    fi
}

# Function to check system requirements
check_system_requirements() {
    log_step "Checking system requirements..."
    
    # Check OS
    if ! grep -q "Red Hat Enterprise Linux.*9" /etc/redhat-release 2>/dev/null; then
        log_warn "This script is designed for RHEL 9. Other distributions may work but are not tested."
    fi
    
    # Check memory (minimum 14GB usable for VMs)
    total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_mem_gb=$((total_mem / 1024 / 1024))
    
    if [ "$total_mem_gb" -lt 14 ]; then
        log_error "Insufficient memory. Required: 14GB+, Available: ${total_mem_gb}GB"
        log_info "Note: This deployment is optimized for systems with 16GB RAM"
        exit 1
    fi
    
    # Check CPU (minimum 4 cores)
    cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 4 ]; then
        log_error "Insufficient CPU cores. Required: 4, Available: $cpu_cores"
        exit 1
    fi
    
    # Check disk space (minimum 80GB for optimized deployment)
    available_space=$(df / | awk 'NR==2 {print $4}')
    available_space_gb=$((available_space / 1024 / 1024))
    
    if [ "$available_space_gb" -lt 80 ]; then
        log_error "Insufficient disk space. Required: 80GB+, Available: ${available_space_gb}GB"
        log_info "Note: This deployment is optimized for smaller resource footprint"
        exit 1
    fi
    
    log_info "System requirements check passed:"
    log_info "  Memory: ${total_mem_gb}GB"
    log_info "  CPU Cores: $cpu_cores"
    log_info "  Disk Space: ${available_space_gb}GB"
}

# Function to prompt for configuration
prompt_configuration() {
    log_step "Configuration setup..."
    
    if [[ "$INTERACTIVE" != "false" ]]; then
        echo ""
        log_info "Please provide the following configuration (press Enter for defaults):"
        echo ""
        
        read -p "Cluster name [$DEFAULT_CLUSTER_NAME]: " CLUSTER_NAME
        CLUSTER_NAME="${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}"
        
        read -p "Number of worker nodes [$DEFAULT_NODE_COUNT]: " NODE_COUNT
        NODE_COUNT="${NODE_COUNT:-$DEFAULT_NODE_COUNT}"
        
        read -p "Alteon ADC IP address [$DEFAULT_ALTEON_IP]: " ALTEON_IP
        ALTEON_IP="${ALTEON_IP:-$DEFAULT_ALTEON_IP}"
        
        read -s -p "Alteon ADC password (required): " ALTEON_PASSWORD
        echo ""
        
        if [[ -z "$ALTEON_PASSWORD" ]]; then
            log_error "Alteon password is required!"
            exit 1
        fi
        
        read -p "VIP pool start IP [$DEFAULT_VIP_POOL_START]: " VIP_POOL_START
        VIP_POOL_START="${VIP_POOL_START:-$DEFAULT_VIP_POOL_START}"
        
        read -p "VIP pool end IP [$DEFAULT_VIP_POOL_END]: " VIP_POOL_END
        VIP_POOL_END="${VIP_POOL_END:-$DEFAULT_VIP_POOL_END}"
        
        read -p "Deploy sample applications? [y/N]: " DEPLOY_SAMPLES
        [[ "$DEPLOY_SAMPLES" =~ ^[Yy]$ ]] && DEPLOY_SAMPLES="true" || DEPLOY_SAMPLES="false"
        
        read -p "Deploy AKC Aggregator for multi-cluster? [y/N]: " DEPLOY_AGGREGATOR
        [[ "$DEPLOY_AGGREGATOR" =~ ^[Yy]$ ]] && DEPLOY_AGGREGATOR="true" || DEPLOY_AGGREGATOR="false"
        
    else
        # Use environment variables or defaults
        CLUSTER_NAME="${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}"
        NODE_COUNT="${NODE_COUNT:-$DEFAULT_NODE_COUNT}"
        ALTEON_IP="${ALTEON_IP:-$DEFAULT_ALTEON_IP}"
        VIP_POOL_START="${VIP_POOL_START:-$DEFAULT_VIP_POOL_START}"
        VIP_POOL_END="${VIP_POOL_END:-$DEFAULT_VIP_POOL_END}"
        BGP_AS_CALICO="${BGP_AS_CALICO:-$DEFAULT_BGP_AS_CALICO}"
        BGP_AS_ALTEON="${BGP_AS_ALTEON:-$DEFAULT_BGP_AS_ALTEON}"
        DEPLOY_SAMPLES="${DEPLOY_SAMPLES:-false}"
        DEPLOY_AGGREGATOR="${DEPLOY_AGGREGATOR:-false}"
        
        if [[ -z "$ALTEON_PASSWORD" ]]; then
            log_error "ALTEON_PASSWORD environment variable is required for non-interactive mode!"
            exit 1
        fi
    fi
    
    # Display configuration
    echo ""
    log_info "Configuration summary:"
    log_info "  Cluster Name: $CLUSTER_NAME"
    log_info "  Worker Nodes: $NODE_COUNT"
    log_info "  Alteon IP: $ALTEON_IP"
    log_info "  VIP Pool: $VIP_POOL_START - $VIP_POOL_END"
    log_info "  Deploy Samples: $DEPLOY_SAMPLES"
    log_info "  Deploy Aggregator: $DEPLOY_AGGREGATOR"
    echo ""
    
    if [[ "$INTERACTIVE" != "false" ]]; then
        read -p "Continue with this configuration? [Y/n]: " CONFIRM
        if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
            log_info "Setup cancelled by user."
            exit 0
        fi
    fi
}

# Function to setup logging
setup_logging() {
    # Create log file
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    sudo chmod 666 "$LOG_FILE"
    
    log_info "Setup started at $(date)"
    log_info "Script version: $SCRIPT_VERSION"
}

# Function to install system prerequisites
install_prerequisites() {
    log_step "Installing system prerequisites..."
    
    # Update system
    log_progress "Updating system packages..."
    sudo dnf update -y >> "$LOG_FILE" 2>&1
    
    # Install base packages
    log_progress "Installing base packages..."
    sudo dnf install -y \
        git curl wget unzip jq \
        firewalld NetworkManager \
        python3 python3-pip \
        sshpass rsync \
        >> "$LOG_FILE" 2>&1
    
    # Install development tools
    log_progress "Installing development tools..."
    sudo dnf groupinstall -y "Development Tools" >> "$LOG_FILE" 2>&1
    
    # Install container runtime
    log_progress "Installing Podman..."
    sudo dnf install -y podman podman-compose >> "$LOG_FILE" 2>&1
    
    # Start and enable Podman socket
    sudo systemctl enable --now podman.socket >> "$LOG_FILE" 2>&1
    sudo usermod -aG podman "$USER"
    
    # Install virtualization packages
    log_progress "Installing virtualization packages..."
    sudo dnf install -y qemu-kvm libvirt virt-install bridge-utils >> "$LOG_FILE" 2>&1
    sudo systemctl enable --now libvirtd >> "$LOG_FILE" 2>&1
    sudo usermod -aG libvirt "$USER"
    
    log_info "System prerequisites installed successfully."
}

# Function to install tools
install_tools() {
    log_step "Installing required tools..."
    
    # Install Terraform
    log_progress "Installing Terraform..."
    sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo >> "$LOG_FILE" 2>&1
    sudo dnf install -y terraform >> "$LOG_FILE" 2>&1
    
    # Install kubectl
    log_progress "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" >> "$LOG_FILE" 2>&1
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl >> "$LOG_FILE" 2>&1
    rm kubectl
    
    # Install Helm
    log_progress "Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 >> "$LOG_FILE" 2>&1
    chmod 700 get_helm.sh
    ./get_helm.sh >> "$LOG_FILE" 2>&1
    rm get_helm.sh
    
    # Install calicoctl
    log_progress "Installing calicoctl..."
    curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o calicoctl >> "$LOG_FILE" 2>&1
    sudo install -o root -g root -m 0755 calicoctl /usr/local/bin/calicoctl >> "$LOG_FILE" 2>&1
    rm calicoctl
    
    # Install additional tools
    log_progress "Installing additional tools..."
    
    # Install yq for YAML processing
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 >> "$LOG_FILE" 2>&1
    sudo chmod +x /usr/local/bin/yq
    
    # Install stern for log viewing
    curl -L https://github.com/stern/stern/releases/latest/download/stern_linux_amd64.tar.gz | tar xz >> "$LOG_FILE" 2>&1
    sudo mv stern /usr/local/bin/stern
    
    log_info "All tools installed successfully."
}

# Function to configure firewall
configure_firewall() {
    log_step "Configuring firewall..."
    
    # Start firewalld
    sudo systemctl enable --now firewalld >> "$LOG_FILE" 2>&1
    
    # Open required ports
    log_progress "Opening required ports..."
    
    # Kubernetes API server
    sudo firewall-cmd --permanent --add-port=6443/tcp >> "$LOG_FILE" 2>&1
    
    # BGP
    sudo firewall-cmd --permanent --add-port=179/tcp >> "$LOG_FILE" 2>&1
    
    # Alteon management
    sudo firewall-cmd --permanent --add-port=443/tcp >> "$LOG_FILE" 2>&1
    sudo firewall-cmd --permanent --add-port=22/tcp >> "$LOG_FILE" 2>&1
    
    # Node communication
    sudo firewall-cmd --permanent --add-port=10250/tcp >> "$LOG_FILE" 2>&1
    sudo firewall-cmd --permanent --add-port=10251/tcp >> "$LOG_FILE" 2>&1
    sudo firewall-cmd --permanent --add-port=10252/tcp >> "$LOG_FILE" 2>&1
    
    # Pod network
    sudo firewall-cmd --permanent --add-port=8472/udp >> "$LOG_FILE" 2>&1
    
    # Monitoring
    sudo firewall-cmd --permanent --add-port=9090/tcp >> "$LOG_FILE" 2>&1  # Prometheus
    sudo firewall-cmd --permanent --add-port=3000/tcp >> "$LOG_FILE" 2>&1  # Grafana
    sudo firewall-cmd --permanent --add-port=9114/tcp >> "$LOG_FILE" 2>&1  # Metrics
    
    # Calico BGP
    sudo firewall-cmd --permanent --add-port=9091/tcp >> "$LOG_FILE" 2>&1
    
    # Reload firewall
    sudo firewall-cmd --reload >> "$LOG_FILE" 2>&1
    
    log_info "Firewall configured successfully."
}

# Function to clone repository
clone_repository() {
    log_step "Cloning AKC infrastructure repository..."
    
    # Create setup directory
    sudo mkdir -p "$SETUP_DIR"
    sudo chown "$USER:$USER" "$SETUP_DIR"
    
    # Clone repository
    if [ -d "$SETUP_DIR/.git" ]; then
        log_progress "Repository already exists, pulling latest changes..."
        cd "$SETUP_DIR"
        git pull origin "$REPO_BRANCH" >> "$LOG_FILE" 2>&1
    else
        log_progress "Cloning repository..."
        git clone -b "$REPO_BRANCH" "$REPO_URL" "$SETUP_DIR" >> "$LOG_FILE" 2>&1
    fi
    
    cd "$SETUP_DIR"
    
    # Make scripts executable
    find scripts/ -name "*.sh" -type f -exec chmod +x {} \; >> "$LOG_FILE" 2>&1
    
    log_info "Repository cloned successfully to $SETUP_DIR"
}

# Function to generate SSH keys
generate_ssh_keys() {
    log_step "Setting up SSH keys..."
    
    SSH_KEY_PATH="$USER_HOME/.ssh/akc_deployment"
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        log_progress "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -C "akc-deployment-$(date +%Y%m%d)" -f "$SSH_KEY_PATH" -N "" >> "$LOG_FILE" 2>&1
        
        # Update cloud-init files with the new public key
        PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")
        
        # Update master cloud-init
        sed -i "s|ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7.*|$PUBLIC_KEY|g" terraform/clusters/cloud-init/master.yaml
        
        # Update worker cloud-init
        sed -i "s|ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7.*|$PUBLIC_KEY|g" terraform/clusters/cloud-init/worker.yaml
        
        log_info "SSH keys generated and configured."
    else
        log_info "SSH keys already exist."
    fi
}

# Function to create configuration files
create_configuration() {
    log_step "Creating configuration files..."
    
    # Create deployment configuration
    cat > config/deployment.conf << EOF
# AKC Infrastructure Deployment Configuration
# Generated by setup script on $(date)

# Cluster Configuration
CLUSTER_NAME="$CLUSTER_NAME"
NODE_COUNT="$NODE_COUNT"

# Alteon Configuration
ALTEON_IP="$ALTEON_IP"
ALTEON_PASSWORD="$ALTEON_PASSWORD"

# Network Configuration
VIP_POOL_START="$VIP_POOL_START"
VIP_POOL_END="$VIP_POOL_END"
BGP_AS_CALICO="$BGP_AS_CALICO"
BGP_AS_ALTEON="$BGP_AS_ALTEON"

# Deployment Options
DEPLOY_SAMPLES="$DEPLOY_SAMPLES"
DEPLOY_AGGREGATOR="$DEPLOY_AGGREGATOR"

# Paths
SSH_KEY_PATH="$SSH_KEY_PATH"
SETUP_DIR="$SETUP_DIR"
EOF
    
    # Create Terraform variables
    mkdir -p terraform/clusters
    cat > terraform/clusters/terraform.tfvars << EOF
# Terraform Variables
# Generated by setup script on $(date)

cluster_name   = "$CLUSTER_NAME"
node_count     = $NODE_COUNT
master_count   = 1
pod_cidr       = "192.168.0.0/16"
service_cidr   = "10.96.0.0/12"
bgp_as_number  = $BGP_AS_CALICO
EOF
    
    log_info "Configuration files created."
}

# Function to run the main deployment
run_deployment() {
    log_step "Starting infrastructure deployment..."
    
    # Export environment variables
    export CLUSTER_NAME
    export NODE_COUNT
    export ALTEON_IP
    export ALTEON_PASSWORD
    export VIP_POOL_START
    export VIP_POOL_END
    export BGP_AS_CALICO
    export BGP_AS_ALTEON
    export DEPLOY_SAMPLES
    export DEPLOY_AGGREGATOR
    
    # Run the main deployment script
    log_progress "Executing deployment script..."
    
    local deploy_args=""
    deploy_args="$deploy_args --cluster-name $CLUSTER_NAME"
    deploy_args="$deploy_args --node-count $NODE_COUNT"
    deploy_args="$deploy_args --alteon-ip $ALTEON_IP"
    deploy_args="$deploy_args --alteon-password $ALTEON_PASSWORD"
    deploy_args="$deploy_args --vip-start $VIP_POOL_START"
    deploy_args="$deploy_args --vip-end $VIP_POOL_END"
    deploy_args="$deploy_args --bgp-calico-as $BGP_AS_CALICO"
    deploy_args="$deploy_args --bgp-alteon-as $BGP_AS_ALTEON"
    
    if [[ "$DEPLOY_AGGREGATOR" == "true" ]]; then
        deploy_args="$deploy_args --deploy-aggregator"
    fi
    
    if [[ "$DEPLOY_SAMPLES" == "true" ]]; then
        deploy_args="$deploy_args --deploy-samples"
    fi
    
    # Run deployment
    ./scripts/deployment/deploy-akc-infrastructure.sh $deploy_args
}

# Function to verify deployment
verify_deployment() {
    log_step "Verifying deployment..."
    
    # Wait a bit for services to stabilize
    sleep 30
    
    log_progress "Checking cluster status..."
    kubectl get nodes -o wide | tee -a "$LOG_FILE"
    
    log_progress "Checking AKC components..."
    kubectl get pods -n akc-system | tee -a "$LOG_FILE"
    
    log_progress "Checking monitoring..."
    kubectl get pods -n monitoring | tee -a "$LOG_FILE"
    
    if [[ "$DEPLOY_SAMPLES" == "true" ]]; then
        log_progress "Checking sample applications..."
        kubectl get services -n akc-demo | tee -a "$LOG_FILE"
    fi
    
    # Test BGP if calicoctl is available
    if command -v calicoctl &>/dev/null; then
        log_progress "Checking BGP status..."
        calicoctl node status | tee -a "$LOG_FILE" || log_warn "BGP status check failed"
    fi
    
    log_info "Deployment verification completed."
}

# Function to display final summary
show_final_summary() {
    log_step "Setup Complete!"
    
    echo ""
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🎉 AKC Infrastructure Setup Complete! 🎉                  ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo ""
    
    # Get service information
    local prometheus_ip=$(kubectl get svc prometheus-lb -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
    local grafana_ip=$(kubectl get svc grafana-lb -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
    
    log_info "📊 Deployment Summary:"
    log_info "   Cluster Name: $CLUSTER_NAME"
    log_info "   Nodes: $(kubectl get nodes --no-headers | wc -l 2>/dev/null || echo "Unknown")"
    log_info "   Alteon IP: $ALTEON_IP"
    log_info "   VIP Pool: $VIP_POOL_START - $VIP_POOL_END"
    echo ""
    
    log_info "🌐 Service URLs:"
    log_info "   Prometheus: http://$prometheus_ip:9090"
    log_info "   Grafana: http://$grafana_ip (admin/admin123)"
    echo ""
    
    log_info "📁 Important Locations:"
    log_info "   Project Directory: $SETUP_DIR"
    log_info "   Kubeconfig: ~/.kube/config"
    log_info "   SSH Keys: $SSH_KEY_PATH"
    log_info "   Configuration: $SETUP_DIR/config/deployment.conf"
    log_info "   Logs: $LOG_FILE"
    echo ""
    
    log_info "🔧 Next Steps:"
    log_info "   1. Verify BGP peering: ssh admin@$ALTEON_IP 'show bgp summary'"
    log_info "   2. Access Grafana dashboard for monitoring"
    log_info "   3. Test sample applications (if deployed)"
    log_info "   4. Review security configurations"
    log_info "   5. Set up backup procedures"
    echo ""
    
    if [[ "$DEPLOY_SAMPLES" == "true" ]]; then
        log_info "🚀 Sample Applications:"
        log_info "   Check services: kubectl get svc -n akc-demo"
        echo ""
    fi
    
    log_info "📚 Documentation:"
    log_info "   Deployment Guide: $SETUP_DIR/docs/deployment-guide.md"
    log_info "   Troubleshooting: $SETUP_DIR/scripts/troubleshooting/akc_techdata.sh"
    echo ""
    
    log_info "✅ Setup completed successfully at $(date)"
    log_info "   Total setup time: $((SECONDS / 60)) minutes"
    echo ""
    
    # Show a reminder about group membership
    log_warn "⚠️  IMPORTANT: You may need to log out and log back in for group membership changes to take effect."
    log_warn "   This affects podman and libvirt group access."
}

# Function to handle cleanup on error
cleanup_on_error() {
    log_error "Setup failed! Cleaning up..."
    
    # Stop any running services
    sudo systemctl stop podman.socket 2>/dev/null || true
    sudo systemctl stop libvirtd 2>/dev/null || true
    
    # Remove partial installations
    rm -rf "$SETUP_DIR" 2>/dev/null || true
    
    log_error "Cleanup completed. Check $LOG_FILE for details."
    exit 1
}

# Function to display usage
usage() {
    echo "AKC Infrastructure Complete Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -i, --interactive       Run in interactive mode (default)"
    echo "  -n, --non-interactive   Run in non-interactive mode (requires env vars)"
    echo "  -r, --repo-url          Repository URL (default: $REPO_URL)"
    echo "  -b, --branch           Repository branch (default: $REPO_BRANCH)"
    echo "  --skip-prereqs         Skip prerequisite installation"
    echo "  --skip-deployment      Skip the actual deployment"
    echo "  --dry-run              Show what would be done without executing"
    echo ""
    echo "Environment Variables (for non-interactive mode):"
    echo "  CLUSTER_NAME           Kubernetes cluster name"
    echo "  NODE_COUNT             Number of worker nodes"
    echo "  ALTEON_IP              Alteon ADC IP address"
    echo "  ALTEON_PASSWORD        Alteon ADC password (required)"
    echo "  VIP_POOL_START         VIP pool start IP"
    echo "  VIP_POOL_END           VIP pool end IP"
    echo "  BGP_AS_CALICO          Calico BGP AS number"
    echo "  BGP_AS_ALTEON          Alteon BGP AS number"
    echo "  DEPLOY_SAMPLES         Deploy sample applications (true/false)"
    echo "  DEPLOY_AGGREGATOR      Deploy AKC Aggregator (true/false)"
    echo ""
    echo "Examples:"
    echo "  # Interactive setup"
    echo "  curl -sSL https://raw.githubusercontent.com/0xGuyG/k8s-akc/main/setup.sh | bash"
    echo ""
    echo "  # Non-interactive setup"
    echo "  ALTEON_PASSWORD=secret DEPLOY_SAMPLES=true ./setup.sh --non-interactive"
    echo ""
    echo "  # Custom repository"
    echo "  ./setup.sh --repo-url https://github.com/myorg/akc-infra.git --branch develop"
}

# Main function
main() {
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Start timing
    SECONDS=0
    
    # Parse command line arguments
    INTERACTIVE="true"
    SKIP_PREREQS="false"
    SKIP_DEPLOYMENT="false"
    DRY_RUN="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -i|--interactive)
                INTERACTIVE="true"
                shift
                ;;
            -n|--non-interactive)
                INTERACTIVE="false"
                shift
                ;;
            -r|--repo-url)
                REPO_URL="$2"
                shift 2
                ;;
            -b|--branch)
                REPO_BRANCH="$2"
                shift 2
                ;;
            --skip-prereqs)
                SKIP_PREREQS="true"
                shift
                ;;
            --skip-deployment)
                SKIP_DEPLOYMENT="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Show banner
    show_banner
    
    # Check if dry run
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
        log_info "Would execute the following steps:"
        log_info "  1. Check system requirements"
        log_info "  2. Prompt for configuration"
        log_info "  3. Install prerequisites (if not skipped)"
        log_info "  4. Clone repository: $REPO_URL"
        log_info "  5. Deploy infrastructure (if not skipped)"
        log_info "  6. Verify deployment"
        exit 0
    fi
    
    # Setup logging
    setup_logging
    
    # Check root
    check_root
    
    # Check system requirements
    check_system_requirements
    
    # Prompt for configuration
    prompt_configuration
    
    # Install prerequisites
    if [[ "$SKIP_PREREQS" != "true" ]]; then
        install_prerequisites
        install_tools
        configure_firewall
    else
        log_info "Skipping prerequisite installation."
    fi
    
    # Clone repository
    clone_repository
    
    # Generate SSH keys
    generate_ssh_keys
    
    # Create configuration
    create_configuration
    
    # Run deployment
    if [[ "$SKIP_DEPLOYMENT" != "true" ]]; then
        run_deployment
        verify_deployment
    else
        log_info "Skipping deployment."
    fi
    
    # Show final summary
    show_final_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi