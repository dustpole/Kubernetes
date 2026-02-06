#!/usr/bin/env bash
# Script to install and configure a Kubernetes Worker using k8s
# Written by Dustin Pollreis

# Variables
DISCOVERY_TOKEN_HASH=""
TOKEN=""
KUBERNETES_VER="v1.35"
CONTROL_PLANE_IP="10.0.3.2"


echo "Starting Kubernetes 1.35 single-node setup..."

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
# ufw --force enable    # Only if you want ufw active

# Generate default containerd config
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable systemd cgroup driver (required match with kubelet)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable --now containerd

# Install Kubernetes packages (from official pkgs.k8s.io repo)
apt-get update && apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VER}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VER}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Join Cluster
kubeadm join $CONTROL_PLANE_IP:6443 --token $TOKEN --discovery-token-ca-cert-hash sha256:$DISCOVERY_TOKEN_HASH

# Allow kubectl on worker
# mkdir -p ~/.kube
# scp dust@k8s-master-01:~/.kube/config config
# scp config dust@k8s-worker-01:~/.kube/config
# chmod 600 ~/.kube/config

# Verify
# kubectl get nodes
