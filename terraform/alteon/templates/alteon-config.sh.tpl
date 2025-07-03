#!/bin/bash

# Alteon ADC Configuration Script for Kubernetes AKC Integration
# This script configures Alteon ADC for integration with Kubernetes via AKC

set -e

ALTEON_HOST="${alteon_host}"
ALTEON_USER="${alteon_username}"
ALTEON_PASS="${alteon_password}"
BGP_AS="${bgp_as_number}"
CALICO_AS="${calico_bgp_as}"
VIP_START="${vip_pool_start}"
VIP_END="${vip_pool_end}"

# Function to execute Alteon CLI commands
execute_alteon_cmd() {
    local cmd="$1"
    echo "Executing: $cmd"
    sshpass -p "$ALTEON_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$ALTEON_USER@$ALTEON_HOST" "$cmd"
}

# Function to apply configuration file
apply_config_file() {
    local config_file="$1"
    echo "Applying configuration file: $config_file"
    sshpass -p "$ALTEON_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$config_file" "$ALTEON_USER@$ALTEON_HOST:/tmp/"
    execute_alteon_cmd "config; import /tmp/$(basename $config_file); apply; save"
}

echo "Starting Alteon ADC configuration for Kubernetes AKC integration..."

# 1. Basic system configuration
echo "Configuring basic system settings..."
execute_alteon_cmd "config; system; hostname alteon-k8s-akc; commit"

# 2. Configure BGP
echo "Configuring BGP settings..."
execute_alteon_cmd "config; bgp; router-id ${alteon_host}; as-number ${bgp_as_number}; enable; commit"

# 3. Configure BGP neighbors (Kubernetes nodes)
echo "Configuring BGP neighbors..."
%{ for node_ip in kubernetes_nodes ~}
execute_alteon_cmd "config; bgp; neighbor ${node_ip}; remote-as ${calico_bgp_as}; enable; commit"
%{ endfor ~}

# 4. Configure VIP pool
echo "Configuring VIP pool..."
execute_alteon_cmd "config; ip; vip pool k8s-vip-pool; start ${vip_pool_start}; end ${vip_pool_end}; enable; commit"

# 5. Configure Layer 4 optimization
echo "Configuring Layer 4 optimization..."
execute_alteon_cmd "config; slb; advanced; hash-method sip-dip-sport-dport; commit"

# 6. Apply additional configuration files
echo "Applying additional configuration files..."
apply_config_file "alteon-bgp.cfg"
apply_config_file "alteon-vip.cfg"
apply_config_file "alteon-l4.cfg"
apply_config_file "alteon-ssl.cfg"
apply_config_file "alteon-waf.cfg"
apply_config_file "health-checks.cfg"
apply_config_file "monitoring.cfg"

# 7. Save configuration
echo "Saving configuration..."
execute_alteon_cmd "save"

# 8. Verify BGP status
echo "Verifying BGP status..."
execute_alteon_cmd "show bgp summary"

# 9. Verify VIP pool
echo "Verifying VIP pool configuration..."
execute_alteon_cmd "show ip vip pool k8s-vip-pool"

echo "Alteon ADC configuration completed successfully!"
echo "BGP AS Number: ${bgp_as_number}"
echo "Calico Peer AS: ${calico_bgp_as}"
echo "VIP Pool: ${vip_pool_start} - ${vip_pool_end}"
echo "Kubernetes Nodes: ${join(", ", kubernetes_nodes)}"

# 10. Display configuration summary
echo "Configuration Summary:"
execute_alteon_cmd "show running-config | grep -E '(bgp|vip|slb)'"

echo "Next steps:"
echo "1. Verify BGP peering with Kubernetes nodes"
echo "2. Deploy AKC components to Kubernetes cluster"
echo "3. Test service loadbalancing"
echo "4. Configure SSL certificates and policies"