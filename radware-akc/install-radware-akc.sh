#!/bin/bash

# Radware AKC Installation Script
# This script installs the official Radware AKC components

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AKC_INSTALLER="$SCRIPT_DIR/installer/AKC-1-6-0.tgz"
AKC_VERSION="1.6.0"

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

# Function to check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites for Radware AKC installation..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Kubernetes cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster"
        exit 1
    fi
    
    # Check if Helm is available
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if AKC installer exists
    if [ ! -f "$AKC_INSTALLER" ]; then
        log_error "AKC installer not found: $AKC_INSTALLER"
        exit 1
    fi
    
    log_info "All prerequisites met."
}

# Function to extract AKC installer
extract_akc_installer() {
    log_step "Extracting Radware AKC installer..."
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    tar -xzf "$AKC_INSTALLER"
    
    log_info "AKC installer extracted to: $TEMP_DIR"
}

# Function to create AKC namespace
create_namespace() {
    log_step "Creating AKC namespace..."
    
    kubectl create namespace akc-system --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace akc-system name=akc-system --overwrite
    
    log_info "AKC namespace created/verified."
}

# Function to install AKC CRDs
install_crds() {
    log_step "Installing AKC Custom Resource Definitions..."
    
    if [ -d "$TEMP_DIR/crds" ]; then
        kubectl apply -f "$TEMP_DIR/crds/"
        log_info "CRDs installed successfully."
    else
        log_warn "CRD directory not found, skipping CRD installation."
    fi
}

# Function to install AKC Controller
install_akc_controller() {
    log_step "Installing Radware AKC Controller..."
    
    # Check if Helm chart exists
    if [ -f "$TEMP_DIR/akc-controller-*.tgz" ]; then
        CHART_FILE=$(ls "$TEMP_DIR"/akc-controller-*.tgz | head -1)
        
        # Install with Helm
        helm upgrade --install akc-controller "$CHART_FILE" \
            --namespace akc-system \
            --set alteon.host="${ALTEON_HOST:-10.0.0.100}" \
            --set alteon.username="${ALTEON_USER:-admin}" \
            --set alteon.password="${ALTEON_PASSWORD}" \
            --wait --timeout=300s
        
        log_info "AKC Controller installed successfully."
    else
        log_warn "AKC Controller Helm chart not found in installer."
        log_info "Using custom Helm chart instead..."
        
        # Use our custom Helm chart
        helm upgrade --install akc-controller "$SCRIPT_DIR/../helm/akc-controller/" \
            --namespace akc-system \
            --set controller.config.alteon.host="${ALTEON_HOST:-10.0.0.100}" \
            --set controller.config.alteon.password="${ALTEON_PASSWORD}" \
            --wait --timeout=300s
    fi
}

# Function to install AKC Aggregator (if needed)
install_akc_aggregator() {
    if [ "$INSTALL_AGGREGATOR" = "true" ]; then
        log_step "Installing Radware AKC Aggregator..."
        
        if [ -f "$TEMP_DIR/akc-aggregator-*.tgz" ]; then
            CHART_FILE=$(ls "$TEMP_DIR"/akc-aggregator-*.tgz | head -1)
            
            helm upgrade --install akc-aggregator "$CHART_FILE" \
                --namespace akc-system \
                --set alteon.host="${ALTEON_HOST:-10.0.0.100}" \
                --set alteon.username="${ALTEON_USER:-admin}" \
                --set alteon.password="${ALTEON_PASSWORD}" \
                --wait --timeout=300s
            
            log_info "AKC Aggregator installed successfully."
        else
            log_warn "AKC Aggregator Helm chart not found."
        fi
    fi
}

# Function to apply RBAC configuration
apply_rbac() {
    log_step "Applying RBAC configuration..."
    
    # Apply our enhanced RBAC
    kubectl apply -f "$SCRIPT_DIR/../manifests/security/rbac.yaml"
    
    log_info "RBAC configuration applied."
}

# Function to verify installation
verify_installation() {
    log_step "Verifying AKC installation..."
    
    # Check pods
    log_info "Checking AKC pods..."
    kubectl get pods -n akc-system
    
    # Check services
    log_info "Checking AKC services..."
    kubectl get services -n akc-system
    
    # Check CRDs
    log_info "Checking AKC CRDs..."
    kubectl get crds | grep -E "(akc|radware)" || log_warn "No AKC CRDs found"
    
    # Wait for pods to be ready
    log_info "Waiting for AKC pods to be ready..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=akc-controller -n akc-system --timeout=300s || true
}

# Function to show example usage
show_example() {
    log_step "Example AKC Service Configuration"
    
    cat << 'EOF'

To create a service with AKC annotations, use the following example:

apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: default
  annotations:
    # AKC Annotations
    akc.radware.com/lb-algo: roundrobin          # Load balancing algorithm
    akc.radware.com/lb-health-check: http        # Health check type
    akc.radware.com/sslpol: my-ssl-policy        # SSL policy name
    akc.radware.com/cert: my-certificate         # Certificate name
    akc.radware.com/static-ip: "10.0.1.10"       # Static VIP (optional)
  labels:
    AlteonDevice: "true"                          # Enable AKC processing
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - name: https
      port: 443
      targetPort: 80
  externalTrafficPolicy: Local                    # Preserve source IP
  allocateLoadBalancerNodePorts: false            # BGP mode

Example deployment available at: $SCRIPT_DIR/examples/nginx-example.yaml

To deploy the example:
kubectl apply -f $SCRIPT_DIR/examples/nginx-example.yaml

EOF
}

# Function to cleanup
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main installation function
main() {
    echo "=================================================="
    echo "       Radware AKC $AKC_VERSION Installation"
    echo "=================================================="
    echo ""
    
    # Check environment variables
    if [ -z "$ALTEON_PASSWORD" ]; then
        log_error "ALTEON_PASSWORD environment variable is required!"
        echo "Usage: ALTEON_PASSWORD=your-password $0"
        exit 1
    fi
    
    check_prerequisites
    extract_akc_installer
    create_namespace
    apply_rbac
    install_crds
    install_akc_controller
    install_akc_aggregator
    verify_installation
    show_example
    
    echo ""
    echo "=================================================="
    echo "✅ Radware AKC Installation Complete!"
    echo "=================================================="
    echo ""
    log_info "AKC Controller is running in namespace: akc-system"
    log_info "Alteon ADC: ${ALTEON_HOST:-10.0.0.100}"
    log_info "Version: $AKC_VERSION"
    echo ""
    log_info "Next steps:"
    log_info "1. Verify BGP peering between Calico and Alteon"
    log_info "2. Deploy services with AKC annotations"
    log_info "3. Check service external IPs: kubectl get svc"
}

# Run main function
main "$@"