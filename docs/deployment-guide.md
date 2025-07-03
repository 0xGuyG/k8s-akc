# AKC Infrastructure Deployment Guide

This guide provides step-by-step instructions for deploying the complete Alteon Kubernetes Connector (AKC) infrastructure on RHEL 9.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Deployment](#detailed-deployment)
4. [Configuration](#configuration)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Maintenance](#maintenance)

## Prerequisites

### System Requirements

- **RHEL 9** server with minimum:
  - 16GB RAM
  - 4 CPU cores
  - 100GB disk space
  - Network connectivity to Alteon ADC

### Required Software

Install the following tools before deployment:

```bash
# Install Docker/Podman
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Install Terraform
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install -y terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install additional tools
sudo dnf install -y jq git unzip sshpass
```

### Network Requirements

- **BGP connectivity** between Kubernetes nodes and Alteon ADC
- **Firewall rules** for:
  - BGP traffic (TCP 179)
  - Alteon management (TCP 443, 22)
  - Kubernetes API (TCP 6443)
  - Pod network (varies by CNI)

### Alteon ADC Requirements

- Alteon ADC appliance (physical or virtual)
- Management access credentials
- BGP configuration capability
- Sufficient VIP pool allocation

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd kubernetes-akc-infrastructure
```

### 2. Set Environment Variables

```bash
export ALTEON_PASSWORD="your-alteon-password"
export CLUSTER_NAME="akc-cluster"
export ALTEON_IP="10.0.0.100"
```

### 3. Run Deployment Script

```bash
./scripts/deployment/deploy-akc-infrastructure.sh \
    --alteon-password "$ALTEON_PASSWORD" \
    --deploy-samples \
    --deploy-aggregator
```

### 4. Verify Deployment

```bash
kubectl get nodes
kubectl get pods -n akc-system
kubectl get services -n akc-demo
```

## Detailed Deployment

### Phase 1: Infrastructure Setup (Weeks 1-2)

#### Step 1: Prepare Environment

1. **Configure SSH keys:**
   ```bash
   ssh-keygen -t rsa -b 4096 -C "akc-deployment"
   # Add public key to terraform/clusters/cloud-init/master.yaml
   # Add public key to terraform/clusters/cloud-init/worker.yaml
   ```

2. **Set up project structure:**
   ```bash
   cd kubernetes-akc-infrastructure
   ls -la
   # Verify all directories are present
   ```

#### Step 2: Deploy Kubernetes Cluster

1. **Configure cluster parameters:**
   ```bash
   cd terraform/clusters
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings
   ```

2. **Deploy cluster:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Verify cluster:**
   ```bash
   # Copy kubeconfig from master node
   scp k8s@<master-ip>:/home/k8s/.kube/config ~/.kube/config
   kubectl get nodes
   ```

#### Step 3: Configure Calico CNI

1. **Wait for Calico installation:**
   ```bash
   kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n calico-system --timeout=300s
   ```

2. **Configure BGP:**
   ```bash
   cd scripts/bgp-setup
   ./configure-calico-bgp.sh
   ```

### Phase 2: AKC Integration (Weeks 3-4)

#### Step 1: Configure Alteon ADC

1. **Generate Alteon configuration:**
   ```bash
   cd terraform/alteon
   terraform init
   terraform plan -var="alteon_password=$ALTEON_PASSWORD"
   terraform apply
   ```

2. **Apply Alteon configuration:**
   ```bash
   ALTEON_PASS="$ALTEON_PASSWORD" ./alteon-config.sh
   ```

#### Step 2: Deploy AKC Components

1. **Create AKC namespace:**
   ```bash
   kubectl apply -f manifests/security/rbac.yaml
   ```

2. **Deploy AKC Controller:**
   ```bash
   helm install akc-controller helm/akc-controller/ \
       --namespace akc-system \
       --set controller.config.alteon.host="$ALTEON_IP" \
       --set controller.config.alteon.password="$ALTEON_PASSWORD"
   ```

3. **Deploy AKC Aggregator (optional):**
   ```bash
   helm install akc-aggregator helm/akc-aggregator/ \
       --namespace akc-system \
       --set aggregator.config.alteon.host="$ALTEON_IP"
   ```

### Phase 3: Security & Monitoring (Weeks 5-6)

#### Step 1: Apply Security Policies

```bash
kubectl apply -f manifests/security/pod-security-policies.yaml
```

#### Step 2: Deploy Monitoring

```bash
kubectl apply -f monitoring/prometheus/
kubectl apply -f monitoring/grafana/
```

#### Step 3: Configure Alerts

```bash
# Verify AlertManager is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager
```

### Phase 4: Service Mesh (Weeks 7-8)

#### Step 1: Install Istio

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio
istioctl install --set values.defaultRevision=default
```

#### Step 2: Configure Istio with AKC

```bash
# Enable sidecar injection
kubectl label namespace akc-demo istio-injection=enabled

# Deploy service mesh sample
kubectl apply -f manifests/services/sample-services.yaml
```

### Phase 5: CI/CD & Operations (Weeks 9-10)

#### Step 1: Set up CI/CD Pipeline

```bash
# Copy GitLab CI configuration
cp ci-cd/gitlab-ci.yml .gitlab-ci.yml

# Configure environment variables in GitLab:
# - ALTEON_PASSWORD
# - KUBE_CONFIG
# - DEV_ALTEON_HOST
# - STAGING_ALTEON_HOST
# - PROD_ALTEON_HOST
```

#### Step 2: Set up Operational Procedures

```bash
# Create backup directory
mkdir -p /backup/akc

# Set up log rotation
sudo cp docs/logrotate.conf /etc/logrotate.d/akc

# Configure monitoring alerts
kubectl apply -f monitoring/alertmanager/
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `CLUSTER_NAME` | Kubernetes cluster name | `akc-cluster` | No |
| `NODE_COUNT` | Number of worker nodes | `3` | No |
| `ALTEON_IP` | Alteon ADC IP address | `10.0.0.100` | No |
| `ALTEON_PASSWORD` | Alteon ADC password | - | Yes |
| `VIP_POOL_START` | VIP pool start IP | `10.0.1.10` | No |
| `VIP_POOL_END` | VIP pool end IP | `10.0.1.100` | No |
| `BGP_AS_CALICO` | Calico BGP AS number | `65000` | No |
| `BGP_AS_ALTEON` | Alteon BGP AS number | `65001` | No |

### Configuration Files

- `config/deployment.conf` - Main deployment configuration
- `terraform/clusters/terraform.tfvars` - Cluster configuration
- `helm/akc-controller/values.yaml` - AKC Controller settings
- `helm/akc-aggregator/values.yaml` - AKC Aggregator settings

### Service Annotations

Use these annotations on Kubernetes services for AKC integration:

```yaml
metadata:
  annotations:
    akc.radware.com/static-ip: "10.0.1.10"
    akc.radware.com/ssl-policy: "default-ssl-policy"
    akc.radware.com/ssl-cert: "my-cert"
    akc.radware.com/securepath-policy: "waf-policy"
    akc.radware.com/health-check: "http-health-check"
    akc.radware.com/load-balancing-method: "round-robin"
```

## Verification

### 1. Cluster Health

```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### 2. AKC Components

```bash
# Check AKC pods
kubectl get pods -n akc-system

# Check AKC logs
kubectl logs -n akc-system -l app.kubernetes.io/name=akc-controller

# Check AKC configuration
kubectl get configmaps -n akc-system -o yaml
```

### 3. BGP Connectivity

```bash
# Check Calico node status
calicoctl node status

# Check BGP peers
calicoctl get bgppeers

# Check BGP configuration
calicoctl get bgpconfig
```

### 4. Alteon ADC

```bash
# SSH to Alteon and check BGP
ssh admin@$ALTEON_IP
show bgp summary
show bgp neighbors
show ip route bgp
```

### 5. Service Load Balancing

```bash
# Deploy test service
kubectl apply -f manifests/services/sample-services.yaml

# Check service status
kubectl get services -n akc-demo

# Test connectivity
curl http://<service-external-ip>
```

### 6. Monitoring

```bash
# Check monitoring pods
kubectl get pods -n monitoring

# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

## Troubleshooting

### Common Issues

#### 1. Cluster Nodes Not Ready

**Symptoms:**
```bash
kubectl get nodes
# Shows NotReady status
```

**Solutions:**
```bash
# Check kubelet logs
journalctl -u kubelet -f

# Check CNI plugin
kubectl get pods -n calico-system

# Restart kubelet
sudo systemctl restart kubelet
```

#### 2. AKC Pods Failing

**Symptoms:**
```bash
kubectl get pods -n akc-system
# Shows CrashLoopBackOff or Error
```

**Solutions:**
```bash
# Check pod logs
kubectl logs -n akc-system <pod-name>

# Check configuration
kubectl describe configmap -n akc-system akc-config

# Verify Alteon connectivity
telnet $ALTEON_IP 443
```

#### 3. BGP Peering Issues

**Symptoms:**
```bash
calicoctl node status
# Shows BGP peers down
```

**Solutions:**
```bash
# Check BGP configuration
calicoctl get bgppeers -o yaml

# Check firewall rules
sudo firewall-cmd --list-all

# Check Alteon BGP status
ssh admin@$ALTEON_IP "show bgp neighbors"
```

#### 4. Service External IP Pending

**Symptoms:**
```bash
kubectl get services
# Shows EXTERNAL-IP as <pending>
```

**Solutions:**
```bash
# Check AKC controller logs
kubectl logs -n akc-system -l app.kubernetes.io/name=akc-controller

# Verify VIP pool configuration
kubectl get ippools -o yaml

# Check Alteon VIP configuration
ssh admin@$ALTEON_IP "show ip vip"
```

### Diagnostic Tools

#### 1. Technical Data Collection

```bash
# Run comprehensive diagnostic collection
./scripts/troubleshooting/akc_techdata.sh -p "$ALTEON_PASSWORD"

# This creates a comprehensive diagnostic archive
```

#### 2. Network Connectivity Tests

```bash
# Test BGP connectivity
telnet $ALTEON_IP 179

# Test Kubernetes API
kubectl cluster-info

# Test DNS resolution
nslookup kubernetes.default.svc.cluster.local
```

#### 3. Log Analysis

```bash
# AKC Controller logs
kubectl logs -n akc-system -l app.kubernetes.io/name=akc-controller --tail=100

# Calico logs
kubectl logs -n calico-system -l k8s-app=calico-node --tail=100

# System logs
journalctl -u kubelet -n 100
```

## Maintenance

### Regular Tasks

#### Daily
- Monitor cluster resource usage
- Check AKC component health
- Verify BGP peering status
- Review monitoring alerts

#### Weekly
- Update security patches
- Backup cluster configuration
- Review and rotate logs
- Test disaster recovery procedures

#### Monthly
- Update AKC components
- Review and update certificates
- Capacity planning review
- Security audit

### Backup Procedures

#### 1. Cluster Configuration Backup

```bash
#!/bin/bash
# backup-cluster.sh

BACKUP_DIR="/backup/akc/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup kubeconfig
cp ~/.kube/config "$BACKUP_DIR/kubeconfig"

# Backup AKC configuration
kubectl get configmaps -n akc-system -o yaml > "$BACKUP_DIR/akc-configmaps.yaml"
kubectl get secrets -n akc-system -o yaml > "$BACKUP_DIR/akc-secrets.yaml"

# Backup Terraform state
cp terraform/*/terraform.tfstate "$BACKUP_DIR/"

echo "Backup completed: $BACKUP_DIR"
```

#### 2. Certificate Management

```bash
# Check certificate expiration
kubectl get secrets -n akc-system -o json | jq -r '.items[] | select(.type=="kubernetes.io/tls") | "\(.metadata.name): \(.data."tls.crt" | @base64d | split("\n")[1] | @base64d | .[13:25] | todate)"'

# Rotate certificates (example)
kubectl delete secret akc-tls-cert -n akc-system
kubectl create secret tls akc-tls-cert --cert=new-cert.pem --key=new-key.pem -n akc-system
```

### Update Procedures

#### 1. AKC Component Updates

```bash
# Update AKC Controller
helm upgrade akc-controller helm/akc-controller/ \
    --namespace akc-system \
    --reuse-values \
    --set controller.image.tag="new-version"

# Verify update
kubectl rollout status deployment/akc-controller -n akc-system
```

#### 2. Kubernetes Cluster Updates

```bash
# Update cluster nodes (one at a time)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
# Perform OS updates on the node
kubectl uncordon <node-name>
```

### Monitoring and Alerts

#### Key Metrics to Monitor

- **Cluster Health:** Node status, resource utilization
- **AKC Components:** Pod status, restart count, response time
- **BGP Status:** Peer state, route count, state changes
- **Service Load Balancing:** Connection count, response time
- **Security:** Failed authentication attempts, certificate expiration

#### Alert Configurations

```yaml
# Example Prometheus alert
- alert: AKCControllerDown
  expr: up{job="akc-controller"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "AKC Controller is down"
    description: "AKC Controller has been down for more than 5 minutes"
```

## Support

### Getting Help

1. **Documentation:** Check this guide and inline documentation
2. **Logs:** Collect diagnostic information using provided scripts
3. **Community:** Kubernetes and Calico community forums
4. **Vendor Support:** Radware support for AKC-specific issues

### Contact Information

- **Radware Support:** support@radware.com
- **Documentation Issues:** Create issue in repository
- **Emergency:** Use Radware emergency support procedures

---

For additional information and updates, refer to the project repository and Radware documentation.