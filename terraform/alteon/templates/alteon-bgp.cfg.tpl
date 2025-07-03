# Alteon BGP Configuration for Kubernetes Integration
# This configuration enables BGP peering with Calico CNI

# BGP Global Configuration
bgp on
bgp router-id ${bgp_as_number}
bgp as-number ${bgp_as_number}

# BGP Communities for traffic engineering
bgp community-list 1 permit ${bgp_as_number}:100
bgp community-list 2 permit ${bgp_as_number}:200

# Route Maps for prefix control
route-map FROM_CALICO permit 10
  match community 1
  set local-preference 150

route-map TO_CALICO permit 10
  set community ${bgp_as_number}:100

# BGP Neighbors (Kubernetes Nodes)
%{ for node_ip in kubernetes_nodes ~}
bgp neighbor ${node_ip}
  remote-as ${calico_bgp_as}
  description "Kubernetes Node ${node_ip}"
  route-map FROM_CALICO in
  route-map TO_CALICO out
  soft-reconfiguration inbound
  maximum-prefix 1000
  password k8s-bgp-secret
  timers 30 90
  activate
%{ endfor ~}

# BGP Network Advertisements
# Advertise VIP pool to Kubernetes nodes
network 10.0.1.0/24

# BGP Aggregation
# Aggregate routes to reduce routing table size
aggregate-address 10.0.1.0/24 summary-only

# BGP Logging
bgp log-neighbor-changes
bgp deterministic-med

# BGP Dampening to prevent route flapping
bgp dampening 15 1000 2000 60

# BGP Graceful Restart
bgp graceful-restart
bgp graceful-restart restart-time 120
bgp graceful-restart stalepath-time 360

# BGP Best Path Selection
bgp bestpath as-path multipath-relax
bgp bestpath compare-routerid

# BGP Timers
bgp timers 30 90
bgp timers holdtime 180