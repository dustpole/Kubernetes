Below is a **much deeper, more detailed, and more personal README**, written as a **single Markdown file** you can drop directly into your repo.
It keeps your technical rigor, but sounds like it was written by a human who *actually built and runs this cluster* — not a generic template.

I also expanded **software/version badges**, added **design intent**, **why decisions were made**, and **operator notes** that make this feel “living & breathing”.

---

<p align="center">
  <img src="https://img.shields.io/badge/Kubernetes-1.35-326ce5?style=for-the-badge&logo=kubernetes&logoColor=white" />
  <img src="https://img.shields.io/badge/containerd-runtime-575757?style=for-the-badge&logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" />
  <img src="https://img.shields.io/badge/Calico-CNI-3A8AC9?style=for-the-badge" />
  <img src="https://img.shields.io/badge/MetalLB-LoadBalancer-FFB000?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Traefik-Ingress-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white" />
  <img src="https://img.shields.io/badge/Helm-Package_Manager-0F1689?style=for-the-badge&logo=helm&logoColor=white" />
  <img src="https://img.shields.io/badge/Status-Living_%26_Breathing-brightgreen?style=for-the-badge" />
</p>

# Kubernetes Homelab Infrastructure

This repository documents and automates my **personal Kubernetes homelab**, built to closely resemble real-world production clusters while remaining practical for home and lab environments.

The goal is **not** “hello-world Kubernetes.”  
The goal is to understand how Kubernetes behaves **when you own the entire stack** — from kernel flags and cgroups all the way up to ingress routing and load-balanced services.

Everything here exists because I needed it, broke it, fixed it, and wanted it repeatable.

---

## Why This Exists

Most Kubernetes tutorials:
- Abstract away networking
- Hide load balancing behind cloud providers
- Skip audit logging
- Ignore real operational failure modes

This lab intentionally **does the opposite**.

You will:
- Configure your own container runtime
- Install your own CNI
- Provide your own LoadBalancer IPs
- Expose ingress intentionally
- See what breaks when something is misconfigured

If you can run *this* cluster reliably, cloud-managed Kubernetes becomes far less mysterious.

---

## High-Level Architecture

┌─────────────────────────────────────────────────────────────┐
│                    Traefik Ingress Controller               │
│          HTTP / HTTPS Routing + Middleware + Dashboard       │
└─────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│                     MetalLB Load Balancer                   │
│           L2 ARP Advertisement for Service IPs               │
└─────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│                       Calico CNI Network                    │
│        Pod Networking, IPAM, NetworkPolicy Enforcement       │
└─────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│                  Kubernetes Control Plane                   │
│     kube-apiserver | etcd | scheduler | controller-manager  │
└─────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│                        Worker Nodes                         │
│            kubelet + containerd + Pod Workloads             │
└─────────────────────────────────────────────────────────────┘

---
## Design Choices (and Why)

### Kubernetes 1.35
- Matches modern production expectations
- Enforces **cgroup v2**
- Removes legacy behavior early so bad habits don’t form

### containerd (not Docker)
- Docker is no longer the Kubernetes runtime
- containerd is simpler, faster, and closer to production reality

### Calico
- First-class NetworkPolicy support
- No “magic” overlays unless you want them
- Forces you to understand pod-to-pod networking

### MetalLB (L2 Mode)
- What cloud load balancers hide from you
- Perfect for homelabs
- Teaches ARP, IP ownership, and service exposure

### Traefik
- Kubernetes-native ingress
- Automatic service discovery
- Middleware makes security and routing explicit

### Helm
- You *will* need it in real clusters
- Makes versioning and rollbacks survivable

---
## Prerequisites

### Hardware
- Minimum: 2 vCPUs, 2GB RAM per node
- Recommended: 4 vCPUs, 4–8GB RAM
- SSD strongly recommended

### Operating System
- Ubuntu **24.04 LTS**
- Clean install preferred
- Swap disabled (enforced by scripts)

### Networking
- Static IPs or DHCP reservations
- Nodes must reach each other freely
- Control plane IP known ahead of time

---
## Installation Phases

This repo is intentionally **phased**.  
Each phase builds trust in the layer below it.

---
### Phase 1 – Control Plane Bootstrap

**Script:** `master-config.sh`

This script:
- Prepares the OS
- Validates kernel and cgroup state
- Installs containerd
- Installs Kubernetes components
- Initializes the control plane using kubeadm

```bash
chmod +x master-config.sh
sudo ./master-config.sh
````

**Why this script is strict:**

* Kubernetes fails *silently* when prerequisites are wrong
* Failing fast is better than debugging ghost problems later

---
### Phase 2 – Pod Networking (Calico)

**Directory:** `Calico/`

Calico provides:

* Pod IP allocation
* Pod-to-pod routing
* NetworkPolicy enforcement

```bash
cd Calico
chmod +x install-calico.sh
./install-calico.sh
```

You should not proceed until:

```bash
kubectl get pods -n calico-system
```

shows all pods **Running**.

---
### Phase 3 – Load Balancing (MetalLB)

**Directory:** `MetalLB/`

MetalLB:

* Assigns real IPs to Kubernetes Services
* Advertises them on your LAN
* Replaces cloud LoadBalancers

```bash
cd MetalLB
chmod +x install-metallb.sh
./install-metallb.sh
kubectl apply -f metallb-pool.yaml
kubectl apply -f metallb-l2-advertisement.yaml
```

At this point, `type: LoadBalancer` actually works.

---
### Phase 4 – Ingress (Traefik)

**Directory:** `Traefik/`

Traefik handles:

* Ingress routing
* Dashboard access
* Middleware chains (auth, IP allowlists)

```bash
cd Traefik
chmod +x install-traefik.sh
./install-traefik.sh
kubectl apply -f .
```

Ingress now becomes intentional instead of accidental.

---
### Phase 5 – Package Management (Helm)

**Directory:** `Helm/`

Helm becomes mandatory once:

* Apps exceed one YAML file
* Upgrades matter
* Rollbacks matter

```bash
cd Helm
chmod +x install-helm.sh
./install-helm.sh
```

---
### Phase 6 – Worker Nodes

**Template:** `worker-config.example`

Each worker:

* Mirrors control plane OS prep
* Installs containerd + kubelet
* Joins securely via kubeadm token

```bash
cp worker-config.example worker-config.sh
# Edit join values
chmod +x worker-config.sh
sudo ./worker-config.sh
```

---
## Repository Layout

```
.
├── Calico/        # Pod networking
├── Helm/          # Helm installation
├── Kube/          # kubeadm config & audit policy
├── MetalLB/       # Load balancer config
├── Traefik/       # Ingress controller & dashboard
├── master-config.sh
├── worker-config.example
└── README.md
```

---
## Security Notes (Read This)

* This cluster **does not assume trust**
* RBAC is enabled
* NetworkPolicy is available (use it)
* Audit logging exists for a reason
* Secrets never belong in Git

If you wouldn’t do it at work, don’t normalize it here.

---
## Troubleshooting Philosophy

When something breaks:

1. Check kubelet
2. Check networking
3. Check assumptions

Kubernetes rarely lies — it just doesn’t explain itself.

---
## Status

This repository is:

* Actively used
* Actively modified
* Actively broken and repaired

Which is exactly how it should be.

---
## Attribution

Built and maintained by **Dustin Pollreis**
Readme generated with AI assistance, curated and validated by human judgment.

Kubernetes 1.35 • Ubuntu 24.04 • containerd runtime
