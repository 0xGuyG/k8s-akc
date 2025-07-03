# Kubernetes AKC Infrastructure

Complete hybrid Kubernetes infrastructure with Alteon Kubernetes Connector (AKC) integration for production deployment on RHEL 9.

## 🚀 One-Click Setup

Get your complete AKC infrastructure up and running with a single command:

```bash
# Clone and run setup (interactive mode)
git clone https://github.com/0xGuyG/k8s-akc.git
cd k8s-akc
./setup.sh

# Or directly from GitHub (one-liner)
curl -sSL https://raw.githubusercontent.com/0xGuyG/k8s-akc/main/setup.sh | bash
```

### Non-Interactive Setup

For automated deployments, use environment variables:

```bash
export ALTEON_PASSWORD="your-alteon-password"
export CLUSTER_NAME="production-akc"
export DEPLOY_SAMPLES="true"
export DEPLOY_AGGREGATOR="true"

./setup.sh --non-interactive
```

## 📋 What Gets Deployed

The setup script automatically installs and configures:

### ✅ **Infrastructure Components**
- **Kubernetes Cluster** with 2 worker nodes (optimized for 4 vCPU/16GB)
- **Calico CNI** with BGP protocol support
- **Alteon ADC** integration and configuration
- **BGP peering** between Calico and Alteon

### ✅ **AKC Components**
- **Official Radware AKC v1.6.0** installer included
- **AKC Controller** for service load balancing
- **AKC Aggregator** for multi-cluster management (optional)
- **VIP pool management** with automatic allocation
- **SSL/TLS policy** integration

### ✅ **Security & Monitoring**
- **RBAC** configurations with minimal permissions
- **Pod Security Standards** enforcement
- **Network policies** for micro-segmentation
- **Prometheus** monitoring with AKC-specific metrics
- **Grafana** dashboards for visualization

### ✅ **Sample Applications**
- Web application with LoadBalancer service
- API service with WAF protection
- Multi-protocol service examples
- Service mesh integration examples

## 🛠️ Prerequisites

### System Requirements
- **RHEL 9** server with minimum:
  - 14GB+ RAM (optimized for 16GB)
  - 4 CPU cores  
  - 80GB+ disk space (optimized deployment)
- **Network access** to Alteon ADC
- **sudo privileges** for installation

### Required Information
- **Alteon ADC IP address** and credentials
- **VIP pool range** for LoadBalancer services
- **BGP AS numbers** for network integration

## 📖 Quick Start Examples

### 1. Basic Setup (Interactive)
```bash
git clone https://github.com/0xGuyG/k8s-akc.git
cd k8s-akc
./setup.sh
```
Follow the prompts to configure your deployment.

### 2. Production Setup (Non-Interactive)
```bash
export ALTEON_PASSWORD="SecurePassword123"
export CLUSTER_NAME="prod-akc-cluster"
export NODE_COUNT="5"
export ALTEON_IP="192.168.1.100"
export VIP_POOL_START="192.168.1.200"
export VIP_POOL_END="192.168.1.250"
export DEPLOY_AGGREGATOR="true"

./setup.sh --non-interactive
```

### 3. Development Setup with Samples
```bash
export ALTEON_PASSWORD="DevPassword123"
export DEPLOY_SAMPLES="true"
export CLUSTER_NAME="dev-akc"

./setup.sh --non-interactive
```

### 4. Custom Repository Setup
```bash
./setup.sh --repo-url https://github.com/myorg/custom-akc-infra.git --branch develop
```

## 🔧 Configuration Options

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ALTEON_PASSWORD` | Alteon ADC password | - | ✅ |
| `CLUSTER_NAME` | Kubernetes cluster name | `akc-cluster` | ❌ |
| `NODE_COUNT` | Number of worker nodes | `2` | ❌ |
| `ALTEON_IP` | Alteon ADC IP address | `10.0.0.100` | ❌ |
| `VIP_POOL_START` | VIP pool start IP | `10.0.1.10` | ❌ |
| `VIP_POOL_END` | VIP pool end IP | `10.0.1.100` | ❌ |
| `BGP_AS_CALICO` | Calico BGP AS number | `65000` | ❌ |
| `BGP_AS_ALTEON` | Alteon BGP AS number | `65001` | ❌ |
| `DEPLOY_SAMPLES` | Deploy sample applications | `false` | ❌ |
| `DEPLOY_AGGREGATOR` | Deploy AKC Aggregator | `false` | ❌ |

### Command Line Options

```bash
./setup.sh [OPTIONS]

Options:
  -h, --help              Show help message
  -i, --interactive       Run in interactive mode (default)
  -n, --non-interactive   Run in non-interactive mode
  -r, --repo-url          Custom repository URL
  -b, --branch           Repository branch
  --skip-prereqs         Skip prerequisite installation
  --skip-deployment      Skip deployment (setup only)
  --dry-run              Show what would be done
```

## 🎯 What Happens During Setup

### Phase 1: System Preparation (2-5 minutes)
- ✅ Check system requirements (14GB+ RAM, 4 vCPU, 80GB+ disk)
- ✅ Install Podman, Terraform, kubectl, Helm
- ✅ Configure firewall rules for Kubernetes and BGP
- ✅ Set up SSH keys for cluster access

### Phase 2: Repository Setup (1-2 minutes)
- ✅ Clone infrastructure repository
- ✅ Generate configuration files
- ✅ Set up project structure

### Phase 3: Infrastructure Deployment (10-15 minutes)
- ✅ Deploy Kubernetes cluster with Terraform
- ✅ Configure Calico CNI with BGP
- ✅ Set up Alteon ADC integration
- ✅ Establish BGP peering

### Phase 4: AKC Component Deployment (5-10 minutes)
- ✅ Deploy AKC Controller and Aggregator
- ✅ Configure VIP pool management
- ✅ Set up SSL and WAF policies
- ✅ Apply security configurations

### Phase 5: Monitoring & Verification (3-5 minutes)
- ✅ Deploy Prometheus and Grafana
- ✅ Configure monitoring dashboards
- ✅ Deploy sample applications (if requested)
- ✅ Verify all components are running

## 🔍 Verification Commands

After setup completes, verify your deployment:

```bash
# Check cluster status
kubectl get nodes -o wide

# Check AKC components
kubectl get pods -n akc-system

# Check BGP peering
calicoctl node status

# Check monitoring
kubectl get pods -n monitoring

# Check sample applications (if deployed)
kubectl get services -n akc-demo

# Access Grafana dashboard
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin123)
```

## 📊 Service URLs

After deployment, access these services:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | `http://<grafana-ip>:3000` | admin/admin123 |
| **Prometheus** | `http://<prometheus-ip>:9090` | None |
| **Sample Web App** | `http://<service-ip>` | None |
| **Sample API** | `https://<api-ip>` | None |

## 🚨 Troubleshooting

### Common Issues

#### Setup Fails with Permission Errors
```bash
# Ensure user has sudo access
sudo -v

# Check group membership
groups $USER
```

#### Docker/Virtualization Issues
```bash
# Restart services
sudo systemctl restart docker libvirtd

# Check status
sudo systemctl status docker libvirtd
```

#### BGP Peering Fails
```bash
# Check firewall
sudo firewall-cmd --list-ports

# Verify Alteon connectivity
telnet $ALTEON_IP 179
```

#### AKC Pods Won't Start
```bash
# Check logs
kubectl logs -n akc-system -l app.kubernetes.io/name=akc-controller

# Verify configuration
kubectl get configmaps -n akc-system -o yaml
```

### Diagnostic Tools

```bash
# Comprehensive diagnostic collection
./scripts/troubleshooting/akc_techdata.sh -p "$ALTEON_PASSWORD"

# Check specific components
kubectl get pods --all-namespaces
kubectl get services --all-namespaces
calicoctl node status
```

## 📚 Documentation

- **[Deployment Guide](docs/deployment-guide.md)** - Detailed deployment instructions
- **[Architecture Overview](docs/architecture.md)** - System architecture and design
- **[Troubleshooting Guide](docs/troubleshooting.md)** - Common issues and solutions
- **[Operations Manual](docs/operations.md)** - Day-to-day operations
- **[Security Guide](docs/security.md)** - Security best practices

## 🔄 Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │   Alteon ADC    │    │   External      │
│   Cluster       │◄──►│                 │◄──►│   Users         │
│                 │BGP │   Load Balancer │    │                 │
│ ┌─────────────┐ │    │                 │    │                 │
│ │ AKC         │ │    │ ┌─────────────┐ │    │                 │
│ │ Controller  │ │    │ │ VIP Pool    │ │    │                 │
│ └─────────────┘ │    │ │ Management  │ │    │                 │
│ ┌─────────────┐ │    │ └─────────────┘ │    │                 │
│ │ Calico CNI  │ │    │ ┌─────────────┐ │    │                 │
│ │ + BGP       │ │    │ │ SSL/WAF     │ │    │                 │
│ └─────────────┘ │    │ │ Policies    │ │    │                 │
└─────────────────┘    │ └─────────────┘ │    └─────────────────┘
                       └─────────────────┘
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with the setup script
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: Create an issue in this repository
- **Documentation**: Check the `docs/` directory
- **Emergency**: Use diagnostic tools in `scripts/troubleshooting/`

---

**Ready to deploy?** Run `./setup.sh` and get your AKC infrastructure running in minutes! 🚀