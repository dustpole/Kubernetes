#!/usr/bin/env bash
# Script to install and configure a Kubernetes Control Plane using kubeadm
# Written by Dustin Pollreis
# Targets: Ubuntu 24.04 LTS, single-node control-plane, containerd runtime
# Kubernetes version: 1.35

set -euo pipefail  # Exit on error, undefined vars, pipeline failures

# Variables
KUBERNETES_VER="1.35"
CALICO_VER="3.31.3"
MetalLB_VER="0.15.3"

echo "Starting Kubernetes setup..."

# Install basic tools
apt-get update
apt-get install -y iputils-ping dnsutils htop tree git apache2-utils #ufw

# Set timezone (Chicago)
timedatectl set-timezone America/Chicago
timedatectl

# Remove swap (permanently)
swapoff -a
sed -i '/\s\+swap\s\+/ s/^/# /' /etc/fstab

# Kernel modules for container networking
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl settings for Kubernetes networking
cat <<EOF | tee /etc/sysctl.d/99-kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# IMPORTANT: Check for cgroup v2
if [[ "$(stat -fc %T /sys/fs/cgroup/)" != "cgroup2fs" ]]; then
    echo "ERROR: Kubernetes 1.35 requires cgroup v2 (unified hierarchy)."
    exit 1
fi
echo "cgroup v2 detected → good."

# Install containerd from official repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y containerd.io

# Firewall configuration
# ufw allow 6443/tcp    # Kubernetes API server
# ufw allow 10250/tcp   # Kubelet API
# ufw allow 10259/tcp   # kube-scheduler
# ufw allow 10257/tcp   # kube-controller-manager
# ufw allow 2222/tcp    # SSH
# ufw --force enable    # ufw enable

# Generate default containerd config
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable systemd cgroup driver (required match with kubelet)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable --now containerd

# Install Kubernetes packages (from official pkgs.k8s.io repo)
apt-get update && apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VER}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VER}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Copy audit policy file
cp ./Kube/kube-audit-policy.yaml /etc/kubernetes/audit-policy.yaml

# Run kubeadm init with your config
echo "Running kubeadm init... (this may take a few minutes)"
kubeadm init --config ./Kube/init-config.yaml | tee kubeadm-init.log

# Get the current user's home directory, UID, and GID
USER_HOME=$(eval echo ~$SUDO_USER)
USER_UID=$(id -u $SUDO_USER)
USER_GID=$(id -g $SUDO_USER)

# Configure kubectl for the current user
mkdir -p "$USER_HOME/.kube"
cp -i /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
chown "$USER_UID:$USER_GID" "$USER_HOME/.kube/config"
mkdir -p "/root/.kube"
cp /etc/kubernetes/admin.conf /root/.kube/config

# Remove the master node taint to allow scheduling pods on control-plane node
kubectl taint nodes k8s-master-01 node-role.kubernetes.io/control-plane:NoSchedule-

sleep 10

# Install Calico CNI
echo "Installing Calico CNI ${CALICO_VER}..."
./Calico/install-calico.sh "$CALICO_VER"

sleep 10

# Verify Calico installation
echo "Waiting for Calico pods to be in 'Running' state..."
kubectl get pods -n kube-system | grep calico

# Install MetalLB Load Balancer
echo "Installing MetalLB ${MetalLB_VER} (Layer 2 mode)..."
./MetalLB/install-metallb.sh "$MetalLB_VER"

sleep 10

# Install Helm
echo "Installing Helm..."
./Helm/install-helm.sh

sleep 10

# Install Traefik Ingress Controller
echo "Installing Traefik Ingress Controller..."
./Traefik/install-traefik.sh

echo 'For service installation logs check /<service>/install-*.log files for details.'
echo "Logs saved to kubeadm-init.log"
echo "Kubernetes setup complete!"
