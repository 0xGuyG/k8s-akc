#!/bin/bash

# AKC Infrastructure Deployment Script
# This script orchestrates the complete deployment of AKC infrastructure

set -e

# Script configuration
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default configuration
DEFAULT_CLUSTER_NAME="akc-cluster"
DEFAULT_NODE_COUNT="3"
DEFAULT_ALTEON_IP="10.0.0.100"
DEFAULT_VIP_POOL_START="10.0.1.10"
DEFAULT_VIP_POOL_END="10.0.1.100"
DEFAULT_BGP_AS_CALICO="65000"
DEFAULT_BGP_AS_ALTEON="65001"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Function to display script banner
show_banner() {
    echo "========================================================"
    echo "        AKC Infrastructure Deployment Script"
    echo "                Version $SCRIPT_VERSION"
    echo "========================================================"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v podman >/dev/null 2>&1 || missing_tools+=("podman")
    command -v jq >/dev/null 2>&1 || missing_tools+=("jq")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check if running as root (required for some operations)
    if [[ $EUID -eq 0 ]] && [[ "$ALLOW_ROOT" != "true" ]]; then
        log_warn "Running as root is not recommended. Set ALLOW_ROOT=true to override."
    fi
    
    # Check available disk space (minimum 20GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 20971520 ]; then  # 20GB in KB
        log_warn "Less than 20GB disk space available. Deployment may fail."
    fi
    
    log_info "All prerequisites met."
}

# Function to load configuration
load_configuration() {
    log_step "Loading configuration..."
    
    # Set defaults
    CLUSTER_NAME="${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}"
    NODE_COUNT="${NODE_COUNT:-$DEFAULT_NODE_COUNT}"
    ALTEON_IP="${ALTEON_IP:-$DEFAULT_ALTEON_IP}"
    VIP_POOL_START="${VIP_POOL_START:-$DEFAULT_VIP_POOL_START}"
    VIP_POOL_END="${VIP_POOL_END:-$DEFAULT_VIP_POOL_END}"
    BGP_AS_CALICO="${BGP_AS_CALICO:-$DEFAULT_BGP_AS_CALICO}"
    BGP_AS_ALTEON="${BGP_AS_ALTEON:-$DEFAULT_BGP_AS_ALTEON}"
    
    # Load from config file if exists
    local config_file="$PROJECT_ROOT/config/deployment.conf"
    if [ -f "$config_file" ]; then
        log_info "Loading configuration from $config_file"
        source "$config_file"
    fi
    
    # Display configuration
    log_info "Configuration:"
    log_info "  Cluster Name: $CLUSTER_NAME"
    log_info "  Node Count: $NODE_COUNT"
    log_info "  Alteon IP: $ALTEON_IP"
    log_info "  VIP Pool: $VIP_POOL_START - $VIP_POOL_END"
    log_info "  Calico BGP AS: $BGP_AS_CALICO"
    log_info "  Alteon BGP AS: $BGP_AS_ALTEON"
}

# Function to deploy infrastructure with Terraform
deploy_infrastructure() {
    log_step "Deploying infrastructure with Terraform..."
    
    cd "$PROJECT_ROOT/terraform/clusters"
    
    # Initialize Terraform
    log_info "Initializing Terraform for clusters..."
    terraform init
    
    # Plan deployment
    log_info "Planning cluster deployment..."
    terraform plan \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="node_count=$NODE_COUNT" \
        -var="bgp_as_number=$BGP_AS_CALICO" \
        -out=tfplan
    
    # Apply deployment
    log_info "Deploying Kubernetes cluster..."
    terraform apply -auto-approve tfplan
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    sleep 60
    
    # Get cluster info
    MASTER_IPS=$(terraform output -json master_ips | jq -r '.[]')
    WORKER_IPS=$(terraform output -json worker_ips | jq -r '.[]')
    
    log_info "Master nodes: $MASTER_IPS"
    log_info "Worker nodes: $WORKER_IPS"
    
    cd "$PROJECT_ROOT"
}

# Function to configure networking
configure_networking() {
    log_step "Configuring networking..."
    
    cd "$PROJECT_ROOT/terraform/networking"
    
    # Initialize and deploy networking
    terraform init
    terraform plan \
        -var="bgp_as_number=$BGP_AS_CALICO" \
        -var="alteon_bgp_peers=[{ip_address=\"$ALTEON_IP\",as_number=$BGP_AS_ALTEON}]" \
        -var="vip_pool_cidr=10.0.1.0/24" \
        -out=tfplan-network
    
    terraform apply -auto-approve tfplan-network
    
    cd "$PROJECT_ROOT"
}

# Function to configure Alteon ADC
configure_alteon() {
    log_step "Configuring Alteon ADC..."
    
    if [ -z "$ALTEON_PASSWORD" ]; then
        log_warn "ALTEON_PASSWORD not set. Skipping Alteon configuration."
        log_info "Please configure Alteon manually using the generated scripts."
        return
    fi
    
    cd "$PROJECT_ROOT/terraform/alteon"
    
    # Generate Alteon configuration
    terraform init
    terraform plan \
        -var="alteon_host=$ALTEON_IP" \
        -var="alteon_password=$ALTEON_PASSWORD" \
        -var="kubernetes_nodes=[\"$MASTER_IPS\",\"$WORKER_IPS\"]" \
        -var="bgp_as_number=$BGP_AS_ALTEON" \
        -var="calico_bgp_as=$BGP_AS_CALICO" \
        -var="vip_pool_start=$VIP_POOL_START" \
        -var="vip_pool_end=$VIP_POOL_END" \
        -out=tfplan-alteon
    
    terraform apply -auto-approve tfplan-alteon
    
    # Execute Alteon configuration script
    log_info "Executing Alteon configuration script..."
    ALTEON_PASS="$ALTEON_PASSWORD" ./alteon-config.sh
    
    cd "$PROJECT_ROOT"
}

# Function to setup kubectl context
setup_kubectl() {
    log_step "Setting up kubectl context..."
    
    # Copy kubeconfig from master node
    local master_ip=$(echo "$MASTER_IPS" | head -n1)
    
    log_info "Copying kubeconfig from master node..."
    mkdir -p ~/.kube
    scp -o StrictHostKeyChecking=no k8s@"$master_ip":/home/k8s/.kube/config ~/.kube/config
    
    # Test kubectl connectivity
    if kubectl cluster-info &>/dev/null; then
        log_info "kubectl configured successfully"
        kubectl get nodes
    else
        log_error "Failed to configure kubectl"
        exit 1
    fi
}

# Function to configure Calico BGP
configure_calico_bgp() {
    log_step "Configuring Calico BGP..."
    
    # Set environment variables for BGP configuration script
    export ALTEON_IP
    export ALTEON_BGP_AS="$BGP_AS_ALTEON"
    export CALICO_BGP_AS="$BGP_AS_CALICO"
    export VIP_POOL_CIDR="10.0.1.0/24"
    export CLUSTER_NAME
    
    # Run BGP configuration script
    "$PROJECT_ROOT/scripts/bgp-setup/configure-calico-bgp.sh"
}

# Function to deploy AKC components
deploy_akc_components() {
    log_step "Deploying AKC components..."
    
    # Create AKC namespace
    kubectl create namespace akc-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply security manifests
    log_info "Applying security configurations..."
    kubectl apply -f "$PROJECT_ROOT/manifests/security/"
    
    # Check if using official Radware AKC installer
    if [ -f "$PROJECT_ROOT/radware-akc/installer/AKC-1-6-0.tgz" ]; then
        log_info "Using official Radware AKC installer..."
        
        # Set environment variables for Radware installer
        export ALTEON_HOST="$ALTEON_IP"
        export ALTEON_USER="${ALTEON_USER:-admin}"
        export ALTEON_PASSWORD="$ALTEON_PASSWORD"
        export INSTALL_AGGREGATOR="$DEPLOY_AGGREGATOR"
        
        # Run Radware AKC installer
        cd "$PROJECT_ROOT/radware-akc"
        ./install-radware-akc.sh
        cd "$PROJECT_ROOT"
    else
        log_info "Using custom Helm charts for AKC deployment..."
        
        # Deploy AKC Controller
        log_info "Deploying AKC Controller..."
        helm upgrade --install akc-controller \
            "$PROJECT_ROOT/helm/akc-controller/" \
            --namespace akc-system \
            --set controller.config.alteon.host="$ALTEON_IP" \
            --set controller.config.alteon.password="$ALTEON_PASSWORD" \
            --set controller.config.bgp.asNumber="$BGP_AS_ALTEON" \
            --set controller.config.vipPool.start="$VIP_POOL_START" \
            --set controller.config.vipPool.end="$VIP_POOL_END" \
            --wait --timeout=300s
        
        # Deploy AKC Aggregator (if multi-cluster)
        if [ "$DEPLOY_AGGREGATOR" = "true" ]; then
            log_info "Deploying AKC Aggregator..."
            helm upgrade --install akc-aggregator \
                "$PROJECT_ROOT/helm/akc-aggregator/" \
                --namespace akc-system \
                --set aggregator.config.alteon.host="$ALTEON_IP" \
                --set aggregator.config.alteon.password="$ALTEON_PASSWORD" \
                --wait --timeout=300s
        fi
    fi
    
    # Verify deployment
    kubectl get pods -n akc-system
    kubectl get services -n akc-system
}

# Function to deploy monitoring
deploy_monitoring() {
    log_step "Deploying monitoring stack..."
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Prometheus
    log_info "Deploying Prometheus..."
    kubectl apply -f "$PROJECT_ROOT/monitoring/prometheus/"
    
    # Deploy Grafana
    log_info "Deploying Grafana..."
    kubectl apply -f "$PROJECT_ROOT/monitoring/grafana/"
    
    # Wait for monitoring to be ready
    log_info "Waiting for monitoring components to be ready..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
    
    # Get monitoring service URLs
    local prometheus_ip=$(kubectl get svc prometheus-lb -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
    local grafana_ip=$(kubectl get svc grafana-lb -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
    
    log_info "Monitoring deployed successfully!"
    log_info "Prometheus: http://$prometheus_ip:9090"
    log_info "Grafana: http://$grafana_ip (admin/admin123)"
}

# Function to deploy sample applications
deploy_sample_apps() {
    if [ "$DEPLOY_SAMPLES" = "true" ]; then
        log_step "Deploying sample applications..."
        kubectl apply -f "$PROJECT_ROOT/manifests/services/sample-services.yaml"
        
        log_info "Sample applications deployed. Check with:"
        log_info "kubectl get services -n akc-demo"
    fi
}

# Function to run post-deployment tests
run_tests() {
    log_step "Running post-deployment tests..."
    
    # Test cluster connectivity
    log_info "Testing cluster connectivity..."
    kubectl get nodes
    kubectl get pods --all-namespaces
    
    # Test AKC components
    log_info "Testing AKC components..."
    kubectl get pods -n akc-system
    kubectl logs -n akc-system -l app.kubernetes.io/name=akc-controller --tail=10
    
    # Test BGP status (if calicoctl available)
    if command -v calicoctl &>/dev/null; then
        log_info "Testing BGP status..."
        calicoctl node status || log_warn "BGP status check failed"
    fi
    
    # Test monitoring
    log_info "Testing monitoring endpoints..."
    kubectl get pods -n monitoring
    
    log_info "All tests completed!"
}

# Function to display deployment summary
show_summary() {
    log_step "Deployment Summary"
    
    echo ""
    echo "========================================================"
    echo "           AKC Infrastructure Deployment Complete"
    echo "========================================================"
    echo ""
    
    # Cluster information
    echo "Cluster Information:"
    echo "  Name: $CLUSTER_NAME"
    echo "  Nodes: $(kubectl get nodes --no-headers | wc -l)"
    echo "  Master IP: $(echo "$MASTER_IPS" | head -n1)"
    echo ""
    
    # AKC information
    echo "AKC Configuration:"
    echo "  Namespace: akc-system"
    echo "  Alteon IP: $ALTEON_IP"
    echo "  VIP Pool: $VIP_POOL_START - $VIP_POOL_END"
    echo "  BGP AS (Calico): $BGP_AS_CALICO"
    echo "  BGP AS (Alteon): $BGP_AS_ALTEON"
    echo ""
    
    # Service URLs
    echo "Service URLs:"
    local prometheus_ip=$(kubectl get svc prometheus-lb -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
    local grafana_ip=$(kubectl get svc grafana-lb -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
    
    echo "  Prometheus: http://$prometheus_ip:9090"
    echo "  Grafana: http://$grafana_ip (admin/admin123)"
    echo ""
    
    # Next steps
    echo "Next Steps:"
    echo "  1. Verify BGP peering on Alteon: show bgp summary"
    echo "  2. Test sample applications: kubectl get svc -n akc-demo"
    echo "  3. Configure SSL certificates and policies"
    echo "  4. Set up monitoring alerts"
    echo "  5. Review security configurations"
    echo ""
    
    # Important files
    echo "Important Files:"
    echo "  Kubeconfig: ~/.kube/config"
    echo "  Terraform State: terraform/*/terraform.tfstate"
    echo "  Logs: /var/log/akc-deployment.log"
    echo ""
    
    echo "========================================================"
}

# Function to cleanup on error
cleanup_on_error() {
    log_error "Deployment failed. Cleaning up..."
    
    # Cleanup Helm releases
    helm uninstall akc-controller -n akc-system 2>/dev/null || true
    helm uninstall akc-aggregator -n akc-system 2>/dev/null || true
    
    # Cleanup namespaces
    kubectl delete namespace akc-system 2>/dev/null || true
    kubectl delete namespace monitoring 2>/dev/null || true
    kubectl delete namespace akc-demo 2>/dev/null || true
    
    log_info "Cleanup completed. Check logs for details."
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -c, --cluster-name      Cluster name (default: $DEFAULT_CLUSTER_NAME)"
    echo "  -n, --node-count        Number of worker nodes (default: $DEFAULT_NODE_COUNT)"
    echo "  -a, --alteon-ip         Alteon IP address (default: $DEFAULT_ALTEON_IP)"
    echo "  -p, --alteon-password   Alteon password (required)"
    echo "  --vip-start             VIP pool start IP (default: $DEFAULT_VIP_POOL_START)"
    echo "  --vip-end               VIP pool end IP (default: $DEFAULT_VIP_POOL_END)"
    echo "  --bgp-calico-as         Calico BGP AS number (default: $DEFAULT_BGP_AS_CALICO)"
    echo "  --bgp-alteon-as         Alteon BGP AS number (default: $DEFAULT_BGP_AS_ALTEON)"
    echo "  --deploy-aggregator     Deploy AKC Aggregator (default: false)"
    echo "  --deploy-samples        Deploy sample applications (default: false)"
    echo "  --skip-tests            Skip post-deployment tests"
    echo "  --dry-run               Show what would be deployed without executing"
    echo ""
    echo "Environment Variables:"
    echo "  ALTEON_PASSWORD         Alteon ADC password"
    echo "  ALLOW_ROOT              Allow running as root (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0 --alteon-password mypassword"
    echo "  $0 -c my-cluster -n 5 --deploy-samples"
    echo "  ALTEON_PASSWORD=secret $0 --deploy-aggregator"
}

# Main deployment function
main() {
    show_banner
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            -n|--node-count)
                NODE_COUNT="$2"
                shift 2
                ;;
            -a|--alteon-ip)
                ALTEON_IP="$2"
                shift 2
                ;;
            -p|--alteon-password)
                ALTEON_PASSWORD="$2"
                shift 2
                ;;
            --vip-start)
                VIP_POOL_START="$2"
                shift 2
                ;;
            --vip-end)
                VIP_POOL_END="$2"
                shift 2
                ;;
            --bgp-calico-as)
                BGP_AS_CALICO="$2"
                shift 2
                ;;
            --bgp-alteon-as)
                BGP_AS_ALTEON="$2"
                shift 2
                ;;
            --deploy-aggregator)
                DEPLOY_AGGREGATOR="true"
                shift
                ;;
            --deploy-samples)
                DEPLOY_SAMPLES="true"
                shift
                ;;
            --skip-tests)
                SKIP_TESTS="true"
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
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN MODE - No changes will be made"
        load_configuration
        show_summary
        exit 0
    fi
    
    # Execute deployment steps
    check_prerequisites
    load_configuration
    deploy_infrastructure
    configure_networking
    setup_kubectl
    configure_calico_bgp
    configure_alteon
    deploy_akc_components
    deploy_monitoring
    deploy_sample_apps
    
    if [ "$SKIP_TESTS" != "true" ]; then
        run_tests
    fi
    
    show_summary
    
    log_info "AKC infrastructure deployment completed successfully!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi