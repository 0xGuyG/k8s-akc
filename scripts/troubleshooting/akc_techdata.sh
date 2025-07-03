#!/bin/bash

# AKC Technical Data Collection Script
# This script collects diagnostic information for troubleshooting AKC deployment issues

set -e

# Configuration
SCRIPT_VERSION="1.0.0"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="akc_techdata_${TIMESTAMP}"
ALTEON_IP="${ALTEON_IP:-10.0.0.100}"
ALTEON_USER="${ALTEON_USER:-admin}"
NAMESPACES="akc-system,calico-system,monitoring,kube-system"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi
    
    # Check calicoctl (optional)
    if command -v calicoctl &> /dev/null; then
        log_info "calicoctl found - will collect Calico specific data"
        CALICOCTL_AVAILABLE=true
    else
        log_warn "calicoctl not found - some Calico data will be missing"
        CALICOCTL_AVAILABLE=false
    fi
    
    # Check sshpass for Alteon (optional)
    if command -v sshpass &> /dev/null; then
        log_info "sshpass found - will attempt Alteon data collection"
        SSHPASS_AVAILABLE=true
    else
        log_warn "sshpass not found - Alteon data collection will be skipped"
        SSHPASS_AVAILABLE=false
    fi
}

# Function to create output directory structure
create_output_directory() {
    log_info "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"/{kubernetes,calico,akc,alteon,network,logs}
}

# Function to collect basic cluster information
collect_cluster_info() {
    log_info "Collecting cluster information..."
    
    {
        echo "=== Cluster Info ==="
        kubectl cluster-info
        echo ""
        
        echo "=== Kubectl Version ==="
        kubectl version --client
        echo ""
        
        echo "=== Server Version ==="
        kubectl version --short 2>/dev/null || kubectl version
        echo ""
        
        echo "=== Node Information ==="
        kubectl get nodes -o wide
        echo ""
        
        echo "=== Node Details ==="
        kubectl describe nodes
        echo ""
        
        echo "=== Cluster Resources ==="
        kubectl top nodes 2>/dev/null || echo "Metrics server not available"
        echo ""
        
    } > "$OUTPUT_DIR/kubernetes/cluster-info.txt" 2>&1
}

# Function to collect namespace information
collect_namespace_info() {
    log_info "Collecting namespace information..."
    
    {
        echo "=== All Namespaces ==="
        kubectl get namespaces -o wide
        echo ""
        
        for ns in $(echo $NAMESPACES | tr ',' ' '); do
            if kubectl get namespace "$ns" &>/dev/null; then
                echo "=== Namespace: $ns ==="
                kubectl get all -n "$ns" -o wide
                echo ""
                
                echo "=== Events in $ns ==="
                kubectl get events -n "$ns" --sort-by='.lastTimestamp'
                echo ""
                
                echo "=== ConfigMaps in $ns ==="
                kubectl get configmaps -n "$ns" -o yaml
                echo ""
                
                echo "=== Secrets in $ns ==="
                kubectl get secrets -n "$ns"
                echo ""
            else
                echo "Namespace $ns not found"
                echo ""
            fi
        done
        
    } > "$OUTPUT_DIR/kubernetes/namespace-info.txt" 2>&1
}

# Function to collect AKC specific information
collect_akc_info() {
    log_info "Collecting AKC component information..."
    
    {
        echo "=== AKC System Overview ==="
        kubectl get all -n akc-system -o wide 2>/dev/null || echo "AKC system namespace not found"
        echo ""
        
        echo "=== AKC Controller Logs ==="
        kubectl logs -n akc-system -l app.kubernetes.io/name=akc-controller --tail=1000 2>/dev/null || echo "AKC Controller not found"
        echo ""
        
        echo "=== AKC Aggregator Logs ==="
        kubectl logs -n akc-system -l app.kubernetes.io/name=akc-aggregator --tail=1000 2>/dev/null || echo "AKC Aggregator not found"
        echo ""
        
        echo "=== AKC ConfigMaps ==="
        kubectl get configmaps -n akc-system -o yaml 2>/dev/null || echo "No AKC ConfigMaps found"
        echo ""
        
        echo "=== AKC Secrets ==="
        kubectl get secrets -n akc-system 2>/dev/null || echo "No AKC Secrets found"
        echo ""
        
        echo "=== AKC Custom Resources ==="
        kubectl api-resources --api-group=akc.radware.com 2>/dev/null || echo "No AKC CRDs found"
        echo ""
        
        echo "=== Services with AKC Annotations ==="
        kubectl get services --all-namespaces -o json | jq -r '.items[] | select(.metadata.annotations | keys[] | contains("akc.radware.com")) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || echo "jq not available or no services with AKC annotations"
        echo ""
        
    } > "$OUTPUT_DIR/akc/akc-info.txt" 2>&1
}

# Function to collect Calico information
collect_calico_info() {
    log_info "Collecting Calico information..."
    
    {
        echo "=== Calico System Overview ==="
        kubectl get all -n calico-system -o wide 2>/dev/null || echo "Calico system namespace not found"
        echo ""
        
        echo "=== Tigera Operator ==="
        kubectl get all -n tigera-operator -o wide 2>/dev/null || echo "Tigera operator namespace not found"
        echo ""
        
        echo "=== Calico Node Status ==="
        kubectl get pods -n calico-system -l k8s-app=calico-node -o wide
        echo ""
        
        echo "=== Calico Node Logs ==="
        kubectl logs -n calico-system -l k8s-app=calico-node --tail=500 2>/dev/null || echo "Calico node logs not available"
        echo ""
        
        echo "=== Calico Controller Logs ==="
        kubectl logs -n calico-system -l k8s-app=calico-kube-controllers --tail=500 2>/dev/null || echo "Calico controller logs not available"
        echo ""
        
        if [ "$CALICOCTL_AVAILABLE" = true ]; then
            echo "=== Calico Node Status (calicoctl) ==="
            calicoctl node status 2>/dev/null || echo "calicoctl node status failed"
            echo ""
            
            echo "=== BGP Peer Status ==="
            calicoctl get bgppeers -o yaml 2>/dev/null || echo "No BGP peers configured"
            echo ""
            
            echo "=== BGP Configuration ==="
            calicoctl get bgpconfig -o yaml 2>/dev/null || echo "No BGP configuration found"
            echo ""
            
            echo "=== IP Pools ==="
            calicoctl get ippools -o yaml 2>/dev/null || echo "No IP pools found"
            echo ""
            
            echo "=== Felix Configuration ==="
            calicoctl get felixconfig -o yaml 2>/dev/null || echo "No Felix configuration found"
            echo ""
        fi
        
    } > "$OUTPUT_DIR/calico/calico-info.txt" 2>&1
}

# Function to collect network information
collect_network_info() {
    log_info "Collecting network information..."
    
    {
        echo "=== Network Policies ==="
        kubectl get networkpolicies --all-namespaces -o wide
        echo ""
        
        echo "=== Ingress Resources ==="
        kubectl get ingress --all-namespaces -o wide
        echo ""
        
        echo "=== Services ==="
        kubectl get services --all-namespaces -o wide
        echo ""
        
        echo "=== Endpoints ==="
        kubectl get endpoints --all-namespaces -o wide
        echo ""
        
        echo "=== LoadBalancer Services ==="
        kubectl get services --all-namespaces -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name) - \(.status.loadBalancer.ingress // "Pending")"' 2>/dev/null || echo "jq not available"
        echo ""
        
    } > "$OUTPUT_DIR/network/network-info.txt" 2>&1
}

# Function to collect Alteon information
collect_alteon_info() {
    if [ "$SSHPASS_AVAILABLE" = false ]; then
        log_warn "Skipping Alteon data collection - sshpass not available"
        echo "sshpass not available" > "$OUTPUT_DIR/alteon/alteon-info.txt"
        return
    fi
    
    log_info "Collecting Alteon ADC information..."
    
    if [ -z "$ALTEON_PASS" ]; then
        log_warn "ALTEON_PASS not set, skipping Alteon data collection"
        echo "ALTEON_PASS not set" > "$OUTPUT_DIR/alteon/alteon-info.txt"
        return
    fi
    
    {
        echo "=== Alteon System Information ==="
        sshpass -p "$ALTEON_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "$ALTEON_USER@$ALTEON_IP" "show system" 2>/dev/null || echo "Failed to connect to Alteon"
        echo ""
        
        echo "=== BGP Summary ==="
        sshpass -p "$ALTEON_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "$ALTEON_USER@$ALTEON_IP" "show bgp summary" 2>/dev/null || echo "BGP information not available"
        echo ""
        
        echo "=== BGP Neighbors ==="
        sshpass -p "$ALTEON_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "$ALTEON_USER@$ALTEON_IP" "show bgp neighbors" 2>/dev/null || echo "BGP neighbors not available"
        echo ""
        
        echo "=== IP Routes ==="
        sshpass -p "$ALTEON_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "$ALTEON_USER@$ALTEON_IP" "show ip route" 2>/dev/null || echo "Route information not available"
        echo ""
        
        echo "=== VIP Configuration ==="
        sshpass -p "$ALTEON_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "$ALTEON_USER@$ALTEON_IP" "show running-config | include vip" 2>/dev/null || echo "VIP information not available"
        echo ""
        
        echo "=== SLB Statistics ==="
        sshpass -p "$ALTEON_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "$ALTEON_USER@$ALTEON_IP" "show slb stat" 2>/dev/null || echo "SLB statistics not available"
        echo ""
        
    } > "$OUTPUT_DIR/alteon/alteon-info.txt" 2>&1
}

# Function to collect monitoring information
collect_monitoring_info() {
    log_info "Collecting monitoring information..."
    
    {
        echo "=== Monitoring Namespace ==="
        kubectl get all -n monitoring -o wide 2>/dev/null || echo "Monitoring namespace not found"
        echo ""
        
        echo "=== Prometheus Status ==="
        kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o wide 2>/dev/null || echo "Prometheus not found"
        echo ""
        
        echo "=== Grafana Status ==="
        kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o wide 2>/dev/null || echo "Grafana not found"
        echo ""
        
        echo "=== ServiceMonitor Resources ==="
        kubectl get servicemonitors --all-namespaces -o wide 2>/dev/null || echo "ServiceMonitor CRD not found"
        echo ""
        
        echo "=== PrometheusRule Resources ==="
        kubectl get prometheusrules --all-namespaces -o wide 2>/dev/null || echo "PrometheusRule CRD not found"
        echo ""
        
    } > "$OUTPUT_DIR/logs/monitoring-info.txt" 2>&1
}

# Function to collect system logs
collect_system_logs() {
    log_info "Collecting system logs..."
    
    # Collect logs from key pods
    for ns in $(echo $NAMESPACES | tr ',' ' '); do
        if kubectl get namespace "$ns" &>/dev/null; then
            mkdir -p "$OUTPUT_DIR/logs/$ns"
            
            # Get all pods in namespace
            pods=$(kubectl get pods -n "$ns" -o name 2>/dev/null | sed 's/pod\///')
            
            for pod in $pods; do
                log_debug "Collecting logs for pod $pod in namespace $ns"
                kubectl logs -n "$ns" "$pod" --previous > "$OUTPUT_DIR/logs/$ns/${pod}-previous.log" 2>/dev/null || true
                kubectl logs -n "$ns" "$pod" > "$OUTPUT_DIR/logs/$ns/${pod}-current.log" 2>/dev/null || true
                kubectl describe pod -n "$ns" "$pod" > "$OUTPUT_DIR/logs/$ns/${pod}-describe.txt" 2>/dev/null || true
            done
        fi
    done
}

# Function to collect resource usage
collect_resource_usage() {
    log_info "Collecting resource usage information..."
    
    {
        echo "=== Node Resource Usage ==="
        kubectl top nodes 2>/dev/null || echo "Metrics server not available"
        echo ""
        
        echo "=== Pod Resource Usage ==="
        kubectl top pods --all-namespaces 2>/dev/null || echo "Metrics server not available"
        echo ""
        
        echo "=== Resource Quotas ==="
        kubectl get resourcequotas --all-namespaces -o wide
        echo ""
        
        echo "=== Limit Ranges ==="
        kubectl get limitranges --all-namespaces -o wide
        echo ""
        
        echo "=== Persistent Volumes ==="
        kubectl get pv -o wide
        echo ""
        
        echo "=== Persistent Volume Claims ==="
        kubectl get pvc --all-namespaces -o wide
        echo ""
        
        echo "=== Storage Classes ==="
        kubectl get storageclass -o wide
        echo ""
        
    } > "$OUTPUT_DIR/kubernetes/resource-usage.txt" 2>&1
}

# Function to collect network diagnostics
collect_network_diagnostics() {
    log_info "Collecting network diagnostics..."
    
    {
        echo "=== DNS Resolution Test ==="
        kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null || echo "DNS test failed"
        echo ""
        
        echo "=== Service Connectivity Test ==="
        kubectl get svc --all-namespaces | grep -v "ClusterIP.*<none>" | head -5
        echo ""
        
        echo "=== Network Plugin Information ==="
        kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium)"
        echo ""
        
    } > "$OUTPUT_DIR/network/network-diagnostics.txt" 2>&1
}

# Function to create summary report
create_summary_report() {
    log_info "Creating summary report..."
    
    {
        echo "========================================"
        echo "AKC Technical Data Collection Summary"
        echo "========================================"
        echo "Collection Date: $(date)"
        echo "Script Version: $SCRIPT_VERSION"
        echo "Cluster: $(kubectl config current-context)"
        echo ""
        
        echo "Files Collected:"
        find "$OUTPUT_DIR" -type f -name "*.txt" -o -name "*.log" | sort
        echo ""
        
        echo "Directory Size:"
        du -sh "$OUTPUT_DIR"
        echo ""
        
        echo "Collection Status:"
        echo "- Kubernetes Info: ✓"
        echo "- AKC Components: $([ -f "$OUTPUT_DIR/akc/akc-info.txt" ] && echo "✓" || echo "✗")"
        echo "- Calico Info: $([ -f "$OUTPUT_DIR/calico/calico-info.txt" ] && echo "✓" || echo "✗")"
        echo "- Alteon Info: $([ -f "$OUTPUT_DIR/alteon/alteon-info.txt" ] && echo "✓" || echo "✗")"
        echo "- Network Info: $([ -f "$OUTPUT_DIR/network/network-info.txt" ] && echo "✓" || echo "✗")"
        echo "- Monitoring Info: $([ -f "$OUTPUT_DIR/logs/monitoring-info.txt" ] && echo "✓" || echo "✗")"
        echo ""
        
    } > "$OUTPUT_DIR/SUMMARY.txt"
}

# Function to create archive
create_archive() {
    log_info "Creating archive..."
    
    ARCHIVE_NAME="${OUTPUT_DIR}.tar.gz"
    tar -czf "$ARCHIVE_NAME" "$OUTPUT_DIR"
    
    log_info "Archive created: $ARCHIVE_NAME"
    log_info "Archive size: $(du -sh "$ARCHIVE_NAME" | cut -f1)"
}

# Main execution function
main() {
    echo "========================================"
    echo "AKC Technical Data Collection Script"
    echo "Version: $SCRIPT_VERSION"
    echo "========================================"
    echo ""
    
    check_prerequisites
    create_output_directory
    
    # Collect all information
    collect_cluster_info
    collect_namespace_info
    collect_akc_info
    collect_calico_info
    collect_network_info
    collect_alteon_info
    collect_monitoring_info
    collect_system_logs
    collect_resource_usage
    collect_network_diagnostics
    
    create_summary_report
    create_archive
    
    echo ""
    log_info "Technical data collection completed successfully!"
    log_info "Archive: $ARCHIVE_NAME"
    log_info "Summary: $OUTPUT_DIR/SUMMARY.txt"
    echo ""
    echo "Please provide this archive to Radware support for analysis."
}

# Script usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -a, --alteon-ip     Alteon IP address (default: 10.0.0.100)"
    echo "  -u, --alteon-user   Alteon username (default: admin)"
    echo "  -p, --alteon-pass   Alteon password (required for Alteon data)"
    echo "  -n, --namespaces    Comma-separated list of namespaces to collect"
    echo ""
    echo "Environment Variables:"
    echo "  ALTEON_IP          Alteon IP address"
    echo "  ALTEON_USER        Alteon username"
    echo "  ALTEON_PASS        Alteon password"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Basic collection"
    echo "  $0 -a 192.168.1.100 -u admin -p pass # With Alteon data"
    echo "  ALTEON_PASS=secret $0                # Using environment variable"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -a|--alteon-ip)
            ALTEON_IP="$2"
            shift 2
            ;;
        -u|--alteon-user)
            ALTEON_USER="$2"
            shift 2
            ;;
        -p|--alteon-pass)
            ALTEON_PASS="$2"
            shift 2
            ;;
        -n|--namespaces)
            NAMESPACES="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Run main function
main "$@"