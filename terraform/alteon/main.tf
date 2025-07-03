terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Variables for Alteon ADC configuration
variable "alteon_host" {
  description = "Alteon ADC management IP address"
  type        = string
  default     = "10.0.0.100"
}

variable "alteon_username" {
  description = "Alteon ADC username"
  type        = string
  default     = "admin"
}

variable "alteon_password" {
  description = "Alteon ADC password"
  type        = string
  sensitive   = true
}

variable "kubernetes_nodes" {
  description = "List of Kubernetes node IP addresses"
  type        = list(string)
  default     = []
}

variable "bgp_as_number" {
  description = "BGP AS number for Alteon"
  type        = number
  default     = 65001
}

variable "calico_bgp_as" {
  description = "Calico BGP AS number"
  type        = number
  default     = 65000
}

variable "vip_pool_start" {
  description = "Start IP of VIP pool"
  type        = string
  default     = "10.0.1.10"
}

variable "vip_pool_end" {
  description = "End IP of VIP pool"
  type        = string
  default     = "10.0.1.100"
}

# Generate Alteon configuration script
resource "local_file" "alteon_config_script" {
  filename = "${path.module}/alteon-config.sh"
  content = templatefile("${path.module}/templates/alteon-config.sh.tpl", {
    alteon_host     = var.alteon_host
    alteon_username = var.alteon_username
    alteon_password = var.alteon_password
    kubernetes_nodes = var.kubernetes_nodes
    bgp_as_number   = var.bgp_as_number
    calico_bgp_as   = var.calico_bgp_as
    vip_pool_start  = var.vip_pool_start
    vip_pool_end    = var.vip_pool_end
  })
  file_permission = "0755"
}

# Generate Alteon BGP configuration
resource "local_file" "alteon_bgp_config" {
  filename = "${path.module}/alteon-bgp.cfg"
  content = templatefile("${path.module}/templates/alteon-bgp.cfg.tpl", {
    bgp_as_number   = var.bgp_as_number
    calico_bgp_as   = var.calico_bgp_as
    kubernetes_nodes = var.kubernetes_nodes
  })
}

# Generate Alteon VIP configuration
resource "local_file" "alteon_vip_config" {
  filename = "${path.module}/alteon-vip.cfg"
  content = templatefile("${path.module}/templates/alteon-vip.cfg.tpl", {
    vip_pool_start = var.vip_pool_start
    vip_pool_end   = var.vip_pool_end
  })
}

# Generate Alteon Layer 4 optimization configuration
resource "local_file" "alteon_l4_config" {
  filename = "${path.module}/alteon-l4.cfg"
  content = templatefile("${path.module}/templates/alteon-l4.cfg.tpl", {
    kubernetes_nodes = var.kubernetes_nodes
  })
}

# Generate SSL/TLS policy configuration
resource "local_file" "alteon_ssl_config" {
  filename = "${path.module}/alteon-ssl.cfg"
  content = file("${path.module}/templates/alteon-ssl.cfg.tpl")
}

# Generate SecurePath (WAF) configuration
resource "local_file" "alteon_waf_config" {
  filename = "${path.module}/alteon-waf.cfg"
  content = file("${path.module}/templates/alteon-waf.cfg.tpl")
}

# Generate vDirect configuration for AKC
resource "local_file" "vdirect_config" {
  filename = "${path.module}/vdirect-akc.py"
  content = templatefile("${path.module}/templates/vdirect-akc.py.tpl", {
    alteon_host     = var.alteon_host
    alteon_username = var.alteon_username
    alteon_password = var.alteon_password
    vip_pool_start  = var.vip_pool_start
    vip_pool_end    = var.vip_pool_end
  })
  file_permission = "0755"
}

# Health check configuration
resource "local_file" "health_check_config" {
  filename = "${path.module}/health-checks.cfg"
  content = templatefile("${path.module}/templates/health-checks.cfg.tpl", {
    kubernetes_nodes = var.kubernetes_nodes
  })
}

# Monitoring configuration
resource "local_file" "monitoring_config" {
  filename = "${path.module}/monitoring.cfg"
  content = file("${path.module}/templates/monitoring.cfg.tpl")
}

# Outputs
output "configuration_files" {
  value = {
    main_script      = local_file.alteon_config_script.filename
    bgp_config       = local_file.alteon_bgp_config.filename
    vip_config       = local_file.alteon_vip_config.filename
    l4_config        = local_file.alteon_l4_config.filename
    ssl_config       = local_file.alteon_ssl_config.filename
    waf_config       = local_file.alteon_waf_config.filename
    vdirect_config   = local_file.vdirect_config.filename
    health_checks    = local_file.health_check_config.filename
    monitoring       = local_file.monitoring_config.filename
  }
}

output "alteon_info" {
  value = {
    host          = var.alteon_host
    bgp_as        = var.bgp_as_number
    vip_pool      = "${var.vip_pool_start} - ${var.vip_pool_end}"
    peer_as       = var.calico_bgp_as
  }
  sensitive = false
}