# Kubernetes Homelab Infrastructure

A comprehensive, production-inspired Kubernetes cluster setup designed for home labs and small environments. This repository contains fully automated installation scripts, configuration files, and manifests to deploy a functional Kubernetes cluster with networking, load balancing, and ingress routing capabilities.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation Guide](#installation-guide)
  - [Phase 1: Control Plane Setup](#phase-1-control-plane-setup)
  - [Phase 2: Worker Node Setup](#phase-2-worker-node-setup)
  - [Phase 3: Network Layer](#phase-3-network-layer)
  - [Phase 4: Load Balancing](#phase-4-load-balancing)
  - [Phase 5: Ingress Controller](#phase-5-ingress-controller)
  - [Phase 6: Package Manager](#phase-6-package-manager)
- [File Directory & Purpose](#file-directory--purpose)
- [Configuration Details](#configuration-details)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

---

## Overview

This Kubernetes homelab is built on **Kubernetes 1.35** with a containerized architecture using **containerd** as the container runtime. The cluster is designed to be simple enough for learning and experimentation while maintaining production-grade security practices and logging.

### Key Components

- **Control Plane**: Single-node Kubernetes master using `kubeadm` for high availability management
- **Worker Nodes**: Scalable worker configuration for distributed workloads
- **CNI (Container Network Interface)**: Calico for robust pod-to-pod networking
- **Load Balancing**: MetalLB for simple load balancing in non-cloud environments
- **Ingress Controller**: Traefik for HTTP/HTTPS routing and advanced traffic management
- **Package Manager**: Helm for simplified deployment and management
- **Auditing**: Built-in Kubernetes API audit logging for compliance and troubleshooting

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Traefik Ingress Controller               │
│                    (HTTP/HTTPS Routing)                      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                     MetalLB Load Balancer                    │
│                  (L2 Advertisement Protocol)                 │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────┐
│                      Calico CNI Network                       │
│           (Pod-to-Pod Communication & Network Policy)        │
└──────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────┐
│                  Kubernetes API Server                        │
│                  (Control Plane - 10.0.3.2)                  │
│              RBAC, Pod Security, Admission Control           │
└──────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────┐
│                    Worker Nodes                               │
│                  (Pod Scheduling & Execution)                │
│              containerd Runtime | kubelet Service            │
└──────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before beginning the installation, ensure you have:

1. **Hardware Requirements**:
   - At least 2 CPU cores per node (4+ recommended)
   - Minimum 2GB RAM per node (4GB+ recommended for stable operation)
   - 20GB+ disk space for system and container images

2. **Operating System**:
   - Ubuntu 24.04 LTS (target OS for this setup)
   - Root or sudo access on all machines
   - Network connectivity between master and worker nodes

3. **Network Requirements**:
   - Static IP addresses for all nodes (or properly configured DHCP reservations)
   - Control Plane IP: `10.0.3.2` (configurable in scripts)
   - Pod CIDR: `10.244.0.0/16` (configured in kubeadm init)
   - Unrestricted network traffic between nodes

4. **Tools**:
   - `bash` shell (v4.0+)
   - Basic utilities: `curl`, `wget`, `sed`, `grep`
   - No swap enabled (will be disabled during setup)

---

## Installation Guide

The installation follows a sequential, phased approach. Each phase builds upon the previous one, and scripts are designed to be idempotent where possible.

### Phase 1: Control Plane Setup

**File**: `master-config.sh`

**Purpose**: Initialize the Kubernetes control plane (master node) with all necessary components for cluster management.

**What This Script Does**:

1. **System Preparation**
   - Updates package manager and installs essential tools (ping, DNS tools, git, etc.)
   - Sets timezone to America/Chicago (customize as needed)
   - Disables swap (Kubernetes requirement)

2. **Kernel Configuration**
   - Loads required kernel modules: `overlay` and `br_netfilter`
   - Configures network bridge settings for container networking
   - Enables IP forwarding for proper pod routing

3. **cgroup v2 Validation**
   - Verifies the system uses cgroup v2 (unified hierarchy)
   - Kubernetes 1.35 requires cgroup v2 for proper resource management
   - Exits with error if cgroup v1 is detected

4. **containerd Installation**
   - Installs and configures containerd as the container runtime
   - Creates proper systemd configuration files
   - Sets up CNI (Container Network Interface) prerequisites

5. **Kubernetes Components**
   - Installs `kubeadm` (cluster bootstrapping tool)
   - Installs `kubelet` (node agent)
   - Installs `kubectl` (cluster management CLI)
   - Pins versions to Kubernetes 1.35

6. **Cluster Initialization**
   - Uses `kubeadm init` with `init-config.yaml` for reproducible cluster setup
   - Initializes the API server with security policies
   - Sets up TLS certificates for secure communication
   - Creates kubeconfig for cluster access

**How to Run**:

```bash
# Make the script executable
chmod +x master-config.sh

# Run with sudo (requires root for system configuration)
sudo ./master-config.sh
```

**Expected Output**:
- kubeadm join command saved for worker node configuration
- Admin kubeconfig created at `/etc/kubernetes/admin.conf`
- Control plane pods initialized (check with `kubectl get pods -A`)

**Key Variables** (modify as needed):
```bash
KUBERNETES_VER="1.35"
CALICO_VER="3.31.3"
MetalLB_VER="0.15.3"
```

---

### Phase 2: Worker Node Setup

**File**: `worker-config.example` → `worker-config.sh`

**Purpose**: Configure and join a node to the Kubernetes cluster as a worker.

**Important**: This is an **example template**. You must copy and customize it for each worker node.

**Customization Steps**:

1. **Copy the template**:
   ```bash
   cp worker-config.example worker-config.sh
   ```

2. **Edit the variables**:
   ```bash
   nano worker-config.sh
   ```
   
   Update these critical values:
   - `DISCOVERY_TOKEN_HASH`: From `kubeadm init` output (on master node)
   - `TOKEN`: Bootstrap token (from master `kubeadm init` output)
   - `CONTROL_PLANE_IP`: Master node IP (default: `10.0.3.2`)

3. **Obtain join credentials** (run on master):
   ```bash
   # View existing tokens and join command
   kubeadm token list
   
   # If token expired, create new one
   kubeadm token create --print-join-command
   ```

**What This Script Does**:

1. **System Preparation** (identical to master):
   - Basic tools installation
   - Timezone configuration
   - Swap removal

2. **Kernel & Network Setup** (identical to master):
   - Module loading
   - sysctl configuration
   - cgroup v2 verification

3. **containerd & Kubernetes Installation** (identical to master):
   - Container runtime setup
   - kubelet service installation
   - kubectl for local management

4. **Cluster Join**:
   - Uses bootstrap token to securely join the control plane
   - Updates kubeadm configuration with discovery token hash
   - Registers worker with control plane
   - Kubelet begins reporting node status

**How to Run**:

```bash
# On each worker node
chmod +x worker-config.sh
sudo ./worker-config.sh
```

**Verify Worker Registration** (run on master):

```bash
kubectl get nodes
# Should show worker node with "Ready" status
```

---

### Phase 3: Network Layer - Calico CNI

**Files**: 
- `Calico/install-calico.sh`
- `Calico/calico-policy.yaml` (optional, for network policies)

**Purpose**: Install Calico as the Container Network Interface (CNI), enabling pod-to-pod communication within and across nodes.

**Why Calico?**

- **Scalability**: Designed for large clusters, though works great for homelab
- **Network Policies**: Native support for Kubernetes network policies
- **Performance**: Direct routing without overlay encapsulation (by default)
- **Flexibility**: Can switch to VXLAN encapsulation if needed
- **BGP Support**: Advanced routing for multi-site clusters

**Installation Steps**:

```bash
# Navigate to Calico directory
cd Calico

# Run installation script with Calico version
chmod +x install-calico.sh
./install-calico.sh 3.31.3
```

**What the Script Does**:

1. **Validation**
   - Checks for kubeconfig availability
   - Verifies control plane accessibility
   - Creates logs for troubleshooting

2. **Calico Deployment**
   - Downloads official Calico manifest from GitHub
   - Deploys Calico operator and workload resources
   - Creates `calico-system` namespace for Calico components

3. **CNI Configuration**
   - Installs CNI plugin binaries
   - Configures `/etc/cni/net.d/` for pod network setup
   - Initializes IPAM (IP Address Management)

**Verification**:

```bash
# Check Calico pods running
kubectl get pods -n calico-system

# Verify CNI plugin installed
ls -la /opt/cni/bin/

# Test pod networking
kubectl run -it --rm --image=busybox test-pod -- sh
# Inside pod: ping another pod IP to verify connectivity
```

---

### Phase 4: Load Balancing - MetalLB

**Files**:
- `MetalLB/install-metallb.sh`
- `MetalLB/metallb-pool.yaml`
- `MetalLB/metallb-l2-advertisement.yaml`

**Purpose**: Provide Load Balancer IP allocation for services in non-cloud environments (crucial for homelabs), and advertise these IPs on the local network.

**Why MetalLB?**

- **No Cloud Provider**: Unlike cloud-based Kubernetes, homelab doesn't have automatic LoadBalancer provisioning
- **Simple L2 Mode**: Uses ARP/ND on local network (perfect for homelab)
- **BGP Mode**: Advanced routing for multi-subnet deployments
- **IP Pool Management**: Flexible IP range configuration

**Installation Steps**:

```bash
# Install MetalLB
cd MetalLB
chmod +x install-metallb.sh
./install-metallb.sh 0.15.3

# Configure MetalLB with IP pool
kubectl apply -f metallb-pool.yaml

# Enable L2 advertisement (ARP mode)
kubectl apply -f metallb-l2-advertisement.yaml
```

**Configuration Explanation**:

**metallb-pool.yaml** - Defines available IPs:
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
spec:
  addresses:
  - 10.0.3.200-10.0.3.250  # IP range for LoadBalancer services
```

**metallb-l2-advertisement.yaml** - Announces IPs:
```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
spec:
  ipAddressPools:
  - default
  interfaces:
  - eth0  # Network interface to advertise on
```

**Usage Example**:

```yaml
# Create a LoadBalancer service
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
```

MetalLB will automatically allocate an IP from the pool (e.g., 10.0.3.200).

**Verification**:

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Create a test service and verify IP allocation
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --type=LoadBalancer --port=80
kubectl get svc nginx
# Should show EXTERNAL-IP from the MetalLB pool
```

---

### Phase 5: Ingress Controller - Traefik

**Files**:
- `Traefik/install-traefik.sh`
- `Traefik/traefik-deployment.yaml`
- `Traefik/traefik-dashboard-ingress.yaml`
- `Traefik/traefik-dashboard-middleware.yaml`
- `Traefik/traefik-dashboard-secret.yaml`
- `Traefik/traefik-dashboard-ip-allowlist.yaml`

**Purpose**: Provide HTTP/HTTPS ingress routing with advanced features like middleware, SSL termination, and dashboard access.

**Why Traefik?**

- **Modern & Cloud-Native**: Built for Kubernetes with automatic service discovery
- **Dynamic Configuration**: Updates routes automatically as services are deployed
- **Middleware Support**: Rate limiting, authentication, header manipulation, etc.
- **Dashboard**: Real-time visualization of routes and traffic
- **TLS Management**: Built-in ACME support for Let's Encrypt (can be configured)

**Installation Steps**:

```bash
# Install Traefik via Helm
cd Traefik
chmod +x install-traefik.sh
./install-traefik.sh 3.6

# Apply configuration files in order
kubectl apply -f traefik-deployment.yaml
kubectl apply -f traefik-dashboard-secret.yaml
kubectl apply -f traefik-dashboard-middleware.yaml
kubectl apply -f traefik-dashboard-ingress.yaml
kubectl apply -f traefik-dashboard-ip-allowlist.yaml
```

**Configuration Details**:

**traefik-dashboard-secret.yaml** - Basic auth credentials for dashboard:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dashboard-auth
type: Opaque
stringData:
  users: admin:$apr1$XXXX...  # htpasswd format: admin:password
```

Generate credentials (on master):
```bash
htpasswd -c auth admin
# You'll be prompted for password
# Then encode and add to secret
cat auth | base64
```

**traefik-dashboard-middleware.yaml** - Middleware chain:
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-auth
spec:
  basicAuth:
    secret: dashboard-auth
```

**traefik-dashboard-ingress.yaml** - Expose dashboard via HTTP:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-dashboard
spec:
  rules:
  - host: traefik.local
    http:
      paths:
      - path: /
        backend:
          service:
            name: traefik
            port:
              number: 9000
```

**Using Traefik for Your Services**:

```yaml
# Example: Route traffic to an application
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

**Access Dashboard**:

```bash
# Port forward to access dashboard
kubectl port-forward -n traefik svc/traefik 9000:9000

# Open http://localhost:9000/dashboard/
# Default credentials: admin / (your configured password)
```

**Verification**:

```bash
# Check Traefik pods
kubectl get pods -n traefik

# Verify ingress rules
kubectl get ingress -A
```

---

### Phase 6: Package Manager - Helm

**File**: `Helm/install-helm.sh`

**Purpose**: Install Helm, the Kubernetes package manager, for simplified installation and management of complex applications.

**Why Helm?**

- **Package Management**: Think of it as "apt" for Kubernetes
- **Templating**: Use variables and conditions in manifests
- **Versions**: Track and rollback application versions
- **Dependencies**: Manage multi-component applications as charts
- **Ecosystem**: Thousands of pre-built charts available on Helm Hub

**Installation Steps**:

```bash
cd Helm
chmod +x install-helm.sh
./install-helm.sh
```

**Verification**:

```bash
helm version
helm repo list
```

**Basic Usage Examples**:

```bash
# Add Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Search for charts
helm search repo nginx

# Install a chart (creates a release)
helm install my-release bitnami/nginx

# List installed releases
helm list

# Upgrade a release
helm upgrade my-release bitnami/nginx --set replicaCount=3

# Uninstall a release
helm uninstall my-release
```

---

## File Directory & Purpose

```
.
├── **Root-level Scripts**
│   ├── master-config.sh          # Control plane setup script
│   ├── worker-config.example     # Worker node template (copy & customize)
│   └── worker-config.sh          # Actual worker script (customized copy)
│
├── **Kube/** - Kubernetes Configuration
│   ├── init-config.yaml          # kubeadm initialization manifest
│   │   └── Defines cluster config, API server settings, admission control
│   │
│   └── kube-audit-policy.yaml    # Kubernetes API audit logging rules
│       └── Controls what API calls are logged (security & compliance)
│
├── **Calico/** - Network Connectivity
│   ├── install-calico.sh         # Calico CNI installation script
│   │   └── Deploys pod networking via Calico
│   │
│   └── (optional) calico-policy.yaml
│       └── Kubernetes NetworkPolicy rules for advanced segmentation
│
├── **MetalLB/** - Load Balancing
│   ├── install-metallb.sh             # MetalLB installation script
│   ├── metallb-pool.yaml              # IP address pool configuration
│   └── metallb-l2-advertisement.yaml  # L2 mode (ARP) advertisement
│
├── **Traefik/** - Ingress Controller
│   ├── install-traefik.sh                    # Helm-based installation
│   ├── traefik-deployment.yaml               # Traefik pod configuration
│   ├── traefik-dashboard-ingress.yaml        # Dashboard exposure
│   ├── traefik-dashboard-middleware.yaml     # Auth middleware
│   ├── traefik-dashboard-secret.yaml         # Dashboard credentials
│   ├── traefik-dashboard-secret.example      # Credential template
│   ├── traefik-dashboard-ip-allowlist.yaml   # IP-based access control
│   └── traefik-dashboard-ip-allowlist.example # Allowlist template
│
└── **Helm/** - Package Manager
    └── install-helm.sh           # Helm installation script
```

---

## Configuration Details

### Kubernetes API Server Security (`Kube/init-config.yaml`)

The control plane is configured with security-first approach:

```yaml
apiServer:
  extraArgs:
    - name: authorization-mode
      value: Node,RBAC                    # Role-based access control
    - name: enable-admission-plugins
      value: NodeRestriction,PodSecurity  # Pod security policies
    - name: audit-log-path
      value: /var/log/kubernetes/audit.log        # Audit logging
    - name: audit-policy-file
      value: /etc/kubernetes/audit-policy.yaml    # Audit rules
```

**Why These Settings?**

- **RBAC**: Ensures only authorized users/services can perform actions
- **PodSecurity**: Prevents privileged or insecure containers
- **NodeRestriction**: Prevents nodes from accessing other nodes' data
- **Audit Logging**: Creates permanent record of all API calls for compliance

### Network Configuration

- **Pod CIDR**: `10.244.0.0/16` - Pods get IPs in this range
- **Service CIDR**: `10.96.0.0/12` - Kubernetes services get IPs here (usually)
- **Control Plane IP**: `10.0.3.2` - Master node static IP
- **MetalLB Pool**: `10.0.3.200-10.0.3.250` - LoadBalancer service IP allocation

---

## Security Considerations

1. **Always use static IPs** - Dynamic IPs will break cluster communication
2. **Firewall rules** - Allow necessary ports between nodes (6443, 10250, etc.)
3. **RBAC policies** - Use Kubernetes RBAC for service-to-service communication
4. **Network policies** - Use Calico NetworkPolicy for pod isolation
5. **TLS certificates** - kubeadm automatically handles this, but rotate regularly
6. **Secrets management** - Never commit credentials to git; use example files as templates
7. **API audit logging** - Review audit logs regularly for anomalies

---

## Troubleshooting

### Control Plane won't start

```bash
# Check kubeadm logs
journalctl -u kubelet -n 50

# Verify system requirements
uname -r  # Kernel version
cat /proc/sys/kernel/osrelease

# Check cgroup version
stat -fc %T /sys/fs/cgroup/
```

### Nodes not joining cluster

```bash
# Verify token hasn't expired (tokens last 24 hours)
kubeadm token list

# Create new token on master
kubeadm token create --print-join-command

# Check kubelet status on worker
systemctl status kubelet
journalctl -u kubelet -n 50
```

### Pods not getting IPs (Calico issue)

```bash
# Verify Calico is running
kubectl get pods -n calico-system

# Check pod CIDR is configured
kubectl get nodes -o jsonpath='{.items[0].spec.podCIDR}'

# Restart Calico if needed
kubectl rollout restart daemonset -n calico-system calico-node
```

### MetalLB not assigning IPs

```bash
# Verify MetalLB is running
kubectl get pods -n metallb-system

# Check IPAddressPool
kubectl get ipaddresspool -A

# Check L2Advertisement
kubectl get l2advertisement -A

# Test with a simple LoadBalancer service
kubectl expose deployment nginx --type=LoadBalancer --port=80
kubectl get svc
```

### Can't access Traefik dashboard

```bash
# Verify Traefik is running
kubectl get pods -n traefik

# Port forward to test locally
kubectl port-forward -n traefik svc/traefik 9000:9000

# Check dashboard ingress
kubectl get ingress -A
kubectl describe ingress traefik-dashboard

# Verify credentials are set
kubectl get secret -n traefik dashboard-auth
```

---

## Next Steps & Recommendations

1. **Set up persistent storage** - Add a storage class for stateful applications
2. **Configure monitoring** - Install Prometheus and Grafana for cluster visibility
3. **Enable logging** - Deploy ELK stack or Loki for log aggregation
4. **Backup strategy** - Regularly backup your cluster etcd and workloads
5. **Stay updated** - Keep Kubernetes and component versions current with security patches

---

## License & Attribution

Readme written by AI for Dustin Pollreis
Code written by Dustin Pollreis  
Kubernetes 1.35 | Ubuntu 24.04 LTS | containerd runtime

For questions, issues, or improvements, refer to official documentation:
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Calico Docs](https://docs.tigera.io/calico)
- [MetalLB Docs](https://metallb.io/docs/)
- [Traefik Docs](https://doc.traefik.io/)
- [Helm Docs](https://helm.sh/docs/)