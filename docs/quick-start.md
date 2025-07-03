# Quick Start Guide

Get your AKC infrastructure running in minutes with these simple steps.

## 🚀 Option 1: One-Click Setup (Recommended)

### Interactive Setup
```bash
git clone https://github.com/0xGuyG/k8s-akc.git
cd k8s-akc
./setup.sh
```

### Non-Interactive Setup
```bash
export ALTEON_PASSWORD="your-password"
export DEPLOY_SAMPLES="true"

git clone https://github.com/0xGuyG/k8s-akc.git
cd k8s-akc
./setup.sh --non-interactive
```

### Direct from GitHub
```bash
curl -sSL https://raw.githubusercontent.com/0xGuyG/k8s-akc/main/setup.sh | bash
```

## ⚡ Option 2: Manual Setup

### 1. Prerequisites
```bash
# Install required tools
sudo dnf install -y git docker terraform helm kubectl

# Start services
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

### 2. Clone and Configure
```bash
git clone https://github.com/0xGuyG/k8s-akc.git
cd k8s-akc

# Copy configuration templates
cp config/deployment.conf.example config/deployment.conf
cp terraform/clusters/terraform.tfvars.example terraform/clusters/terraform.tfvars

# Edit with your settings
vim config/deployment.conf
```

### 3. Deploy Infrastructure
```bash
# Deploy cluster
cd terraform/clusters
terraform init && terraform apply

# Deploy AKC components
cd ../..
./scripts/deployment/deploy-akc-infrastructure.sh
```

## 🔧 Configuration Examples

### Minimal Configuration
```bash
export ALTEON_PASSWORD="your-password"
export ALTEON_IP="192.168.1.100"
./setup.sh --non-interactive
```

### Production Configuration
```bash
export ALTEON_PASSWORD="SecurePassword123"
export CLUSTER_NAME="prod-akc"
export NODE_COUNT="5"
export ALTEON_IP="192.168.1.100"
export VIP_POOL_START="192.168.1.200"
export VIP_POOL_END="192.168.1.250"
export DEPLOY_AGGREGATOR="true"
./setup.sh --non-interactive
```

### Development Configuration
```bash
export ALTEON_PASSWORD="DevPassword"
export CLUSTER_NAME="dev-akc"
export DEPLOY_SAMPLES="true"
export NODE_COUNT="2"
./setup.sh --non-interactive
```

## ✅ Verification

After setup, verify your deployment:

```bash
# Check cluster
kubectl get nodes -o wide

# Check AKC components
kubectl get pods -n akc-system

# Check monitoring
kubectl get pods -n monitoring

# Check sample apps (if deployed)
kubectl get services -n akc-demo

# Test BGP peering
calicoctl node status
```

## 🌐 Access Services

### Grafana Dashboard
```bash
# Get Grafana IP
kubectl get svc grafana-lb -n monitoring

# Or port-forward
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin123)
```

### Prometheus
```bash
# Get Prometheus IP
kubectl get svc prometheus-lb -n monitoring

# Or port-forward
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090
```

## 🚨 Common Issues

### Permission Errors
```bash
# Ensure user has sudo access
sudo -v

# Log out and back in for group changes
exit
# Log back in
```

### Service Pending
```bash
# Check AKC controller logs
kubectl logs -n akc-system -l app.kubernetes.io/name=akc-controller

# Verify Alteon connectivity
telnet $ALTEON_IP 443
```

### BGP Issues
```bash
# Check firewall
sudo firewall-cmd --list-ports

# Verify BGP configuration
calicoctl get bgppeers
```

## 📊 What You Get

After successful setup:

- ✅ **Kubernetes cluster** with Calico CNI
- ✅ **AKC Controller** for load balancing
- ✅ **Alteon ADC** integration with BGP
- ✅ **Prometheus + Grafana** monitoring
- ✅ **Security policies** and RBAC
- ✅ **Sample applications** (optional)

## 🔄 Next Steps

1. **Configure SSL certificates** for your services
2. **Set up backup procedures** for cluster data
3. **Configure monitoring alerts** in Grafana
4. **Deploy your applications** with AKC annotations
5. **Review security settings** and policies

## 📚 More Information

- [Deployment Guide](deployment-guide.md) - Detailed instructions
- [Architecture Overview](architecture.md) - System design
- [Troubleshooting](troubleshooting.md) - Common issues
- [Operations Manual](operations.md) - Day-to-day operations

Ready to get started? Run `./setup.sh` and you'll be up and running in minutes! 🎯