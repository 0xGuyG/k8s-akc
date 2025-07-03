#!/bin/bash

# Configure Calico BGP for Alteon Integration
# This script sets up BGP peering between Calico and Alteon ADC

set -e

# Configuration variables
ALTEON_IP="${ALTEON_IP:-10.0.0.100}"
ALTEON_BGP_AS="${ALTEON_BGP_AS:-65001}"
CALICO_BGP_AS="${CALICO_BGP_AS:-65000}"
VIP_POOL_CIDR="${VIP_POOL_CIDR:-10.0.1.0/24}"
CLUSTER_NAME="${CLUSTER_NAME:-akc-cluster}"

echo "Configuring Calico BGP for Alteon integration..."
echo "Alteon IP: $ALTEON_IP"
echo "Alteon BGP AS: $ALTEON_BGP_AS"
echo "Calico BGP AS: $CALICO_BGP_AS"
echo "VIP Pool CIDR: $VIP_POOL_CIDR"

# Function to check if kubectl is available and cluster is accessible
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo "Error: Cannot access Kubernetes cluster"
        exit 1
    fi
}

# Function to wait for Calico to be ready
wait_for_calico() {
    echo "Waiting for Calico to be ready..."
    kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n calico-system --timeout=300s
    kubectl wait --for=condition=Ready pods -l k8s-app=calico-kube-controllers -n calico-system --timeout=300s
}

# Function to create BGP configuration
create_bgp_config() {
    echo "Creating BGP configuration..."
    
    # Create BGP Configuration
    cat <<EOF | kubectl apply -f -
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: true
  asNumber: $CALICO_BGP_AS
  serviceLoadBalancerIPs:
  - cidr: $VIP_POOL_CIDR
  serviceExternalIPs:
  - cidr: $VIP_POOL_CIDR
  listenPort: 179
  bindMode: NodeIP
EOF
}

# Function to create BGP peer for Alteon
create_bgp_peer() {
    echo "Creating BGP peer for Alteon ADC..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: alteon-peer
spec:
  peerIP: $ALTEON_IP
  asNumber: $ALTEON_BGP_AS
  keepOriginalNextHop: false
  password:
    secretKeyRef:
      name: bgp-secrets
      key: alteon-password
EOF
}

# Function to create BGP password secret
create_bgp_secret() {
    echo "Creating BGP password secret..."
    
    kubectl create secret generic bgp-secrets \
        --from-literal=alteon-password="k8s-bgp-secret" \
        -n calico-system \
        --dry-run=client -o yaml | kubectl apply -f -
}

# Function to create IP pool for VIPs
create_ip_pool() {
    echo "Creating IP pool for VIPs..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: vip-pool
spec:
  cidr: $VIP_POOL_CIDR
  disabled: false
  natOutgoing: false
  nodeSelector: all()
  vxlanMode: Never
  ipipMode: Never
  allowedUses:
  - LoadBalancer
  - Service
EOF
}

# Function to configure Felix for BGP
configure_felix() {
    echo "Configuring Felix for BGP..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  routeRefreshInterval: 90s
  interfacePrefix: cali
  chainInsertMode: insert
  defaultEndpointToHostAction: ACCEPT
  iptablesMarkMask: 0xffff0000
  iptablesPostWriteCheckIntervalSecs: 1
  iptablesRefreshInterval: 90s
  ipv6Support: false
  logFilePath: /var/log/calico/felix.log
  prometheusMetricsEnabled: true
  prometheusMetricsPort: 9091
  reportingInterval: 30s
  reportingTTL: 90s
EOF
}

# Function to enable BGP on all nodes
enable_bgp_on_nodes() {
    echo "Enabling BGP on all nodes..."
    
    # Get all node names
    NODES=$(kubectl get nodes -o name | sed 's/node\///')
    
    for node in $NODES; do
        echo "Configuring BGP on node: $node"
        
        cat <<EOF | kubectl apply -f -
apiVersion: projectcalico.org/v3
kind: Node
metadata:
  name: $node
spec:
  bgp:
    ipv4Address: auto
    ipv6Address: none
    asNumber: $CALICO_BGP_AS
    routeReflectorClusterID: ""
  orchRefs:
  - nodeName: $node
    orchestrator: k8s
EOF
    done
}

# Function to verify BGP status
verify_bgp_status() {
    echo "Verifying BGP status..."
    
    # Check if calicoctl is available
    if command -v calicoctl &> /dev/null; then
        echo "BGP Peer Status:"
        calicoctl node status
        
        echo "BGP Configuration:"
        calicoctl get bgpconfig -o yaml
        
        echo "BGP Peers:"
        calicoctl get bgppeers -o yaml
    else
        echo "calicoctl not available, skipping BGP status verification"
        echo "Install calicoctl to verify BGP status manually"
    fi
}

# Function to create test service
create_test_service() {
    echo "Creating test service for BGP verification..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: bgp-test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: bgp-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
  namespace: bgp-test
  annotations:
    akc.radware.com/static-ip: "auto"
spec:
  type: LoadBalancer
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF
    
    echo "Test service created. Check with: kubectl get svc -n bgp-test"
}

# Main execution
main() {
    echo "Starting Calico BGP configuration for Alteon integration..."
    
    check_kubectl
    wait_for_calico
    create_bgp_secret
    create_bgp_config
    create_bgp_peer
    create_ip_pool
    configure_felix
    enable_bgp_on_nodes
    
    echo "Waiting for BGP configuration to take effect..."
    sleep 30
    
    verify_bgp_status
    create_test_service
    
    echo "Calico BGP configuration completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Configure Alteon ADC with BGP peering to Kubernetes nodes"
    echo "2. Verify BGP peering status on Alteon: show bgp summary"
    echo "3. Test service load balancing"
    echo "4. Monitor BGP routes: show ip route bgp"
}

# Run main function
main "$@"