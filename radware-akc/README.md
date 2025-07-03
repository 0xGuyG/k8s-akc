# Radware AKC Official Installer

This directory contains the official Radware AKC (Alteon Kubernetes Connector) installer and configuration examples.

## 📦 Contents

### Installer
- `installer/AKC-1-6-0.tgz` - Official Radware AKC v1.6.0 installer package
- `install-radware-akc.sh` - Installation script for deploying AKC components

### Examples
- `examples/nginx-example.yaml` - Basic NGINX service with AKC annotations
- `examples/web-app-ssl.yaml` - Web application with SSL termination
- `examples/api-waf-protection.yaml` - API service with WAF protection
- `examples/multi-port-service.yaml` - Multi-port service configuration

## 🚀 Installation

### Prerequisites
- Kubernetes cluster with Calico CNI configured
- Alteon ADC with BGP enabled
- kubectl and Helm installed
- Alteon credentials

### Quick Installation
```bash
# Set Alteon credentials
export ALTEON_PASSWORD="your-alteon-password"
export ALTEON_HOST="10.0.0.100"
export ALTEON_USER="admin"

# Run the installer
./install-radware-akc.sh
```

### Installation Options
```bash
# Install with Aggregator for multi-cluster
export INSTALL_AGGREGATOR="true"
./install-radware-akc.sh

# Custom Alteon configuration
export ALTEON_HOST="192.168.1.100"
export ALTEON_USER="myuser"
./install-radware-akc.sh
```

## 📋 AKC Service Annotations

### Required Labels
```yaml
labels:
  AlteonDevice: "true"  # Enable AKC processing for this service
```

### Common Annotations
| Annotation | Description | Example |
|------------|-------------|---------|
| `akc.radware.com/lb-algo` | Load balancing algorithm | `roundrobin`, `leastconnections`, `sourceiphash` |
| `akc.radware.com/lb-health-check` | Health check type | `http`, `https`, `tcp` |
| `akc.radware.com/sslpol` | SSL policy name on Alteon | `web-ssl-policy` |
| `akc.radware.com/cert` | Certificate name on Alteon | `my-certificate` |
| `akc.radware.com/static-ip` | Static VIP assignment | `10.0.1.10` |
| `akc.radware.com/securepath-policy` | WAF policy name | `api-waf-policy` |
| `akc.radware.com/session-persistence` | Session persistence type | `source-ip`, `cookie` |
| `akc.radware.com/connection-timeout` | Connection timeout (seconds) | `30` |
| `akc.radware.com/max-connections` | Maximum connections | `1000` |

### Advanced Annotations
| Annotation | Description | Example |
|------------|-------------|---------|
| `akc.radware.com/rate-limiting` | Rate limiting configuration | `100-per-minute` |
| `akc.radware.com/ddos-protection` | Enable DDoS protection | `enabled` |
| `akc.radware.com/geo-blocking` | Enable geo-blocking | `enabled` |
| `akc.radware.com/whitelist-ips` | IP whitelist (comma-separated) | `10.0.0.0/8,192.168.0.0/16` |
| `akc.radware.com/compression` | Enable compression | `enabled` |
| `akc.radware.com/caching` | Enable caching | `enabled` |

## 🔧 Service Configuration

### Basic LoadBalancer Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    akc.radware.com/lb-algo: roundrobin
    akc.radware.com/lb-health-check: http
  labels:
    AlteonDevice: "true"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
  externalTrafficPolicy: Local           # Preserve source IP
  allocateLoadBalancerNodePorts: false   # BGP mode
```

### SSL Termination Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: ssl-service
  annotations:
    akc.radware.com/sslpol: my-ssl-policy
    akc.radware.com/cert: my-certificate
    akc.radware.com/static-ip: "10.0.1.10"
  labels:
    AlteonDevice: "true"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - name: https
      port: 443
      targetPort: 80
  externalTrafficPolicy: Local
  allocateLoadBalancerNodePorts: false
```

## 🎯 Example Deployments

### Deploy Basic Example
```bash
# Deploy the NGINX example
kubectl apply -f examples/nginx-example.yaml

# Check service status
kubectl get svc k8s-test
kubectl get pods -l app=k8s-test
```

### Deploy SSL Example
```bash
# Deploy web app with SSL
kubectl apply -f examples/web-app-ssl.yaml

# Check external IP assignment
kubectl get svc web-app-ssl -w
```

### Deploy WAF-Protected API
```bash
# Deploy API with WAF
kubectl apply -f examples/api-waf-protection.yaml

# Test the service
curl https://$(kubectl get svc api-service-waf -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

## 🔍 Verification

### Check AKC Components
```bash
# Check AKC pods
kubectl get pods -n akc-system

# Check AKC logs
kubectl logs -n akc-system -l app.kubernetes.io/name=akc-controller

# Check service annotations
kubectl describe svc <service-name>
```

### Verify on Alteon
```bash
# SSH to Alteon
ssh admin@<alteon-ip>

# Check virtual services
show slb virt

# Check real servers
show slb real

# Check BGP routes
show ip route bgp
```

## 🚨 Troubleshooting

### Service IP Pending
```bash
# Check AKC controller logs
kubectl logs -n akc-system -l app.kubernetes.io/name=akc-controller --tail=50

# Verify BGP peering
calicoctl node status

# Check Alteon connectivity
telnet <alteon-ip> 443
```

### Health Check Failures
```bash
# Check pod endpoints
kubectl get endpoints <service-name>

# Verify health check configuration on Alteon
ssh admin@<alteon-ip> "show slb group"
```

### Certificate Issues
```bash
# Verify certificate exists on Alteon
ssh admin@<alteon-ip> "show slb ssl cert"

# Check SSL policy
ssh admin@<alteon-ip> "show slb ssl policy"
```

## 📚 Additional Resources

- [Radware Support Portal](https://portals.radware.com/)
- [AKC Documentation](https://github.com/Radware/AKC)
- [Alteon Documentation](https://portals.radware.com/Customer/Products/Alteon)

## 🆘 Support

For issues specific to the Radware AKC:
- Contact Radware Support: support@radware.com
- Check Radware customer portal
- Review AKC release notes in the installer package