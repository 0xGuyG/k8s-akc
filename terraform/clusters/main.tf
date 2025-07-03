terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Variables
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "akc-cluster"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 1
}

variable "pod_cidr" {
  description = "CIDR for pod network"
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for service network"
  type        = string
  default     = "10.96.0.0/12"
}

variable "bgp_as_number" {
  description = "BGP AS number for Calico"
  type        = number
  default     = 65000
}

# Network configuration
resource "libvirt_network" "akc_network" {
  name   = "${var.cluster_name}-network"
  mode   = "nat"
  domain = "${var.cluster_name}.local"
  
  addresses = ["10.0.0.0/24"]
  
  dhcp {
    enabled = true
  }
  
  dns {
    enabled = true
  }
}

# Cloud-init configuration for master nodes
data "template_file" "master_cloud_init" {
  template = file("${path.module}/cloud-init/master.yaml")
  vars = {
    cluster_name   = var.cluster_name
    pod_cidr       = var.pod_cidr
    service_cidr   = var.service_cidr
    bgp_as_number  = var.bgp_as_number
  }
}

# Cloud-init configuration for worker nodes
data "template_file" "worker_cloud_init" {
  template = file("${path.module}/cloud-init/worker.yaml")
  vars = {
    cluster_name = var.cluster_name
    master_ip    = libvirt_domain.master[0].network_interface[0].addresses[0]
  }
}

# Master nodes
resource "libvirt_volume" "master_disk" {
  count  = var.master_count
  name   = "${var.cluster_name}-master-${count.index}"
  source = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
  size   = 50 * 1024 * 1024 * 1024  # 50GB
}

resource "libvirt_cloudinit_disk" "master_cloudinit" {
  count     = var.master_count
  name      = "${var.cluster_name}-master-${count.index}-cloudinit"
  user_data = data.template_file.master_cloud_init.rendered
}

resource "libvirt_domain" "master" {
  count  = var.master_count
  name   = "${var.cluster_name}-master-${count.index}"
  memory = 6144
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.master_cloudinit[count.index].id

  network_interface {
    network_id     = libvirt_network.akc_network.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.master_disk[count.index].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Worker nodes
resource "libvirt_volume" "worker_disk" {
  count  = var.node_count
  name   = "${var.cluster_name}-worker-${count.index}"
  source = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
  size   = 50 * 1024 * 1024 * 1024  # 50GB
}

resource "libvirt_cloudinit_disk" "worker_cloudinit" {
  count     = var.node_count
  name      = "${var.cluster_name}-worker-${count.index}-cloudinit"
  user_data = data.template_file.worker_cloud_init.rendered
}

resource "libvirt_domain" "worker" {
  count  = var.node_count
  name   = "${var.cluster_name}-worker-${count.index}"
  memory = 3072
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.worker_cloudinit[count.index].id

  network_interface {
    network_id     = libvirt_network.akc_network.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.worker_disk[count.index].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Outputs
output "master_ips" {
  value = libvirt_domain.master[*].network_interface[0].addresses[0]
}

output "worker_ips" {
  value = libvirt_domain.worker[*].network_interface[0].addresses[0]
}

output "cluster_info" {
  value = {
    cluster_name = var.cluster_name
    pod_cidr     = var.pod_cidr
    service_cidr = var.service_cidr
    bgp_as       = var.bgp_as_number
  }
}