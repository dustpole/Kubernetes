#!/usr/bin/env bash
setlocal enabledelayedexpansion

# Script to install and configure a Kubernetes Control Plane using k8s
# Written by Dustin Pollreis

# Variables
KUBERNETES_VER="v1.35"
set "CALICO_VER=v3.28"
set "MetalLB_VER=v0.15.3"

# Install basic tools
apt install iputils-ping dnsutils htop tree git

# Set timezone
timedatectl set-timezone America/Chicago

# Verify
timedatectl

# Remove swap
swapoff -a
sed -i '/\s\+swap\s\+/ s/^/# /' /etc/fstab

# Kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl Networking
cat <<EOF | tee /etc/sysctl.d/99-kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1 
net.bridge.bridge-nf-call-ip6tables = 1 
net.ipv4.ip_forward                 = 1 
EOF

# Apply sysctl params
sysctl --system

# Disable Firewall
ufw disable

# Update package index and install containerd
apt update && apt install -y containerd

# Generate default config
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Edit the config to enable systemd cgroups
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart and enable containerd
systemctl restart containerd
systemctl enable containerd

# Install prerequisites
apt update && apt install -y apt-transport-https ca-certificates curl gpg

# Download the GPG key for the repo and dearmor it 
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VER/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes repo entry
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VER/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Refresh package list
apt update

# Install kubernetes packages
apt update && apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

kubeadm init --config init-config.yaml --upload-certs

# Configure kubectl
mkdir -p $HOME/.kube 
cp /etc/kubernetes/admin.conf $HOME/.kube/config 
chown $$ (id -u): $$(id -g) $HOME/.kube/config

# Verify
kubectl get nodes

# Install Calico CNI
./install-calico.sh "$CALICO_VER"

# Install MetalLB (Layer 2 Mode)
./install-metallb.sh "$MetalLB_VER"

# Install Trafeik Ingress Controller using Helm
./install-traefik.sh

# Verify
kubectl get svc -A


