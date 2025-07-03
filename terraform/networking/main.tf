terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Variables
variable "bgp_as_number" {
  description = "BGP AS number for Calico"
  type        = number
  default     = 65000
}

variable "alteon_bgp_peers" {
  description = "List of Alteon BGP peer configurations"
  type = list(object({
    ip_address = string
    as_number  = number
  }))
  default = [
    {
      ip_address = "10.0.0.100"
      as_number  = 65001
    }
  ]
}

variable "vip_pool_cidr" {
  description = "CIDR block for VIP pool"
  type        = string
  default     = "10.0.1.0/24"
}

# BGP Configuration for Calico
resource "kubernetes_manifest" "bgp_config" {
  manifest = {
    apiVersion = "projectcalico.org/v3"
    kind       = "BGPConfiguration"
    metadata = {
      name = "default"
    }
    spec = {
      logSeverityScreen      = "Info"
      nodeToNodeMeshEnabled  = true
      asNumber              = var.bgp_as_number
      serviceLoadBalancerIPs = [
        {
          cidr = var.vip_pool_cidr
        }
      ]
    }
  }
}

# BGP Peers for Alteon ADC
resource "kubernetes_manifest" "alteon_bgp_peers" {
  for_each = {
    for idx, peer in var.alteon_bgp_peers : idx => peer
  }

  manifest = {
    apiVersion = "projectcalico.org/v3"
    kind       = "BGPPeer"
    metadata = {
      name = "alteon-peer-${each.key}"
    }
    spec = {
      peerIP   = each.value.ip_address
      asNumber = each.value.as_number
    }
  }
}

# IP Pool for LoadBalancer services
resource "kubernetes_manifest" "vip_ip_pool" {
  manifest = {
    apiVersion = "projectcalico.org/v3"
    kind       = "IPPool"
    metadata = {
      name = "vip-pool"
    }
    spec = {
      cidr         = var.vip_pool_cidr
      disabled     = false
      natOutgoing  = false
      nodeSelector = "all()"
    }
  }
}

# Route Reflector configuration for larger clusters
resource "kubernetes_manifest" "route_reflector" {
  count = var.enable_route_reflector ? 1 : 0

  manifest = {
    apiVersion = "projectcalico.org/v3"
    kind       = "Node"
    metadata = {
      name = "route-reflector"
      labels = {
        "route-reflector" = "true"
      }
    }
    spec = {
      bgp = {
        routeReflectorClusterID = "1.0.0.1"
      }
    }
  }
}

# BGP Configuration for Route Reflector
resource "kubernetes_manifest" "route_reflector_config" {
  count = var.enable_route_reflector ? 1 : 0

  manifest = {
    apiVersion = "projectcalico.org/v3"
    kind       = "BGPConfiguration"
    metadata = {
      name = "route-reflector-config"
    }
    spec = {
      logSeverityScreen      = "Info"
      nodeToNodeMeshEnabled  = false
      asNumber              = var.bgp_as_number
    }
  }
}

# Network Policy for AKC components
resource "kubernetes_manifest" "akc_network_policy" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "akc-network-policy"
      namespace = "akc-system"
    }
    spec = {
      podSelector = {
        matchLabels = {
          app = "akc"
        }
      }
      policyTypes = ["Ingress", "Egress"]
      ingress = [
        {
          from = [
            {
              namespaceSelector = {
                matchLabels = {
                  name = "akc-system"
                }
              }
            },
            {
              namespaceSelector = {
                matchLabels = {
                  name = "kube-system"
                }
              }
            }
          ]
          ports = [
            {
              protocol = "TCP"
              port     = 8080
            },
            {
              protocol = "TCP"
              port     = 9443
            }
          ]
        }
      ]
      egress = [
        {
          to = []
          ports = [
            {
              protocol = "TCP"
              port     = 443
            },
            {
              protocol = "TCP"
              port     = 80
            },
            {
              protocol = "TCP"
              port     = 6443
            }
          ]
        }
      ]
    }
  }
}

# Variables for optional features
variable "enable_route_reflector" {
  description = "Enable route reflector for large clusters"
  type        = bool
  default     = false
}

# Outputs
output "bgp_configuration" {
  value = {
    as_number = var.bgp_as_number
    peers     = var.alteon_bgp_peers
    vip_pool  = var.vip_pool_cidr
  }
}

output "network_policies" {
  value = {
    akc_policy = "akc-network-policy created in akc-system namespace"
  }
}