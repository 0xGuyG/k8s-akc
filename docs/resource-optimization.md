# Resource Optimization for 4 vCPU, 16GB RAM Systems

This document outlines the resource optimizations made for systems with limited resources (4 vCPU, 16GB RAM).

## 🎯 Optimization Summary

### **Host Resource Allocation**
- **Total Available**: 4 vCPU, 16GB RAM
- **Host OS Reserved**: ~1GB RAM, 0.5 vCPU
- **Available for VMs**: ~15GB RAM, 3.5 vCPU

### **VM Resource Allocation**
- **Master Node**: 2 vCPU, 6GB RAM
- **Worker Nodes (2x)**: 1 vCPU each, 3GB RAM each
- **Total VM Usage**: 4 vCPU, 12GB RAM
- **Host Overhead**: 3GB RAM remaining for host OS

## 📊 Resource Breakdown

### **Cluster Configuration**
```yaml
# Original vs Optimized
Original:
- Master: 4 vCPU, 8GB RAM
- Workers: 3x (2 vCPU, 4GB RAM each)
- Total: 10 vCPU, 20GB RAM

Optimized:
- Master: 2 vCPU, 6GB RAM
- Workers: 2x (1 vCPU, 3GB RAM each)
- Total: 4 vCPU, 12GB RAM
```

### **Container Resource Limits**
```yaml
# AKC Controller
requests: { cpu: 50m, memory: 64Mi }
limits:   { cpu: 300m, memory: 256Mi }

# AKC Aggregator
requests: { cpu: 100m, memory: 128Mi }
limits:   { cpu: 500m, memory: 512Mi }

# Prometheus
requests: { cpu: 200m, memory: 256Mi }
limits:   { cpu: 500m, memory: 512Mi }

# Grafana
requests: { cpu: 50m, memory: 128Mi }
limits:   { cpu: 200m, memory: 256Mi }
```

## ⚡ Performance Considerations

### **What's Optimized**
- ✅ **Fewer worker nodes** (2 instead of 3)
- ✅ **Reduced VM resources** while maintaining functionality
- ✅ **Lower container resource requests/limits**
- ✅ **Optimized resource quotas** for namespaces
- ✅ **Smaller disk requirements** (80GB vs 100GB)

### **Performance Impact**
- 🟡 **Slightly reduced capacity** for workloads
- 🟡 **Lower redundancy** with 2 workers vs 3
- ✅ **Same functionality** and features
- ✅ **Production-ready** for development/testing
- ✅ **Scalable** - can add more workers later

### **Monitoring Considerations**
- Prometheus retention reduced to 7 days (vs 15 days)
- Grafana plugins limited to essential ones
- Resource monitoring more critical due to constraints

## 🔧 Deployment Commands

### **Standard Deployment**
```bash
export ALTEON_PASSWORD="your-password"
./setup.sh --non-interactive
```

### **Minimal Resource Deployment**
```bash
export ALTEON_PASSWORD="your-password"
export NODE_COUNT="2"
export DEPLOY_SAMPLES="false"  # Skip samples to save resources
./setup.sh --non-interactive
```

### **Development Setup**
```bash
export ALTEON_PASSWORD="your-password"
export NODE_COUNT="2"
export CLUSTER_NAME="dev-akc"
export DEPLOY_SAMPLES="true"
./setup.sh --non-interactive
```

## 📈 Scaling Options

### **Horizontal Scaling**
```bash
# Add more worker nodes later
cd terraform/clusters
terraform apply -var="node_count=3"

# Or scale down if needed
terraform apply -var="node_count=1"
```

### **Vertical Scaling**
```bash
# Increase worker memory (if host allows)
# Edit terraform.tfvars:
worker_memory = 4096  # Increase to 4GB per worker
```

## 🚨 Resource Monitoring

### **Critical Metrics to Watch**
```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods --all-namespaces

# Check resource quotas
kubectl get resourcequota -n akc-system
```

### **Warning Thresholds**
- **Memory usage > 80%** on any node
- **CPU usage > 70%** sustained
- **Disk usage > 85%** on host
- **Pod evictions** due to resource pressure

## 🛠️ Troubleshooting Resource Issues

### **Out of Memory Issues**
```bash
# Check memory pressure
kubectl describe nodes

# Check pod events
kubectl get events --sort-by='.lastTimestamp'

# Reduce resource requests temporarily
kubectl patch deployment <deployment> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"requests":{"memory":"64Mi"}}}]}}}}'
```

### **CPU Throttling**
```bash
# Check CPU metrics
kubectl top nodes
kubectl top pods --containers

# Increase CPU limits if needed
kubectl patch deployment <deployment> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"limits":{"cpu":"500m"}}}]}}}}'
```

### **Disk Space Issues**
```bash
# Clean up unused images
docker system prune -a

# Check disk usage
df -h
du -sh /var/lib/docker

# Clean up old logs
sudo journalctl --vacuum-time=7d
```

## 💡 Optimization Tips

### **Further Resource Savings**
1. **Disable unnecessary services**:
   ```bash
   systemctl disable bluetooth
   systemctl disable cups
   ```

2. **Tune kernel parameters**:
   ```bash
   echo 'vm.swappiness=10' >> /etc/sysctl.conf
   echo 'vm.vfs_cache_pressure=50' >> /etc/sysctl.conf
   ```

3. **Use resource limits strategically**:
   ```yaml
   # Set aggressive limits for non-critical pods
   resources:
     requests: { cpu: 10m, memory: 32Mi }
     limits:   { cpu: 100m, memory: 128Mi }
   ```

### **When to Scale Up**
Consider upgrading host resources if you see:
- Consistent memory pressure warnings
- Pod evictions due to resource constraints
- CPU throttling affecting performance
- Need for additional workloads

## 📋 Resource Planning

### **Current Capacity**
With this optimized setup, you can run:
- ✅ Full AKC infrastructure
- ✅ Monitoring stack (Prometheus + Grafana)
- ✅ 2-3 small application workloads
- ✅ Development and testing workloads

### **Recommended Next Steps**
1. Monitor resource usage for 1 week
2. Identify bottlenecks and adjust accordingly
3. Plan for horizontal scaling if needed
4. Consider host upgrade for production workloads

This optimized configuration provides a fully functional AKC infrastructure while respecting your hardware constraints.