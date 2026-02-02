#!/usr/bin/env bash
# Script to install and configure a Kubernetes Worker using k8s
# Written by Dustin Pollreis

# Variables
DISCOVERY_TOKEN="4ad689c8abc82ee3e8d23284e6ccdc4b60ff43c1d0ca7bce301363ae2143c71b"
TOKEN="uvfgky.y4ysivfcqiqa9q9j"
KUBERNETES_VER="v1.35"
CONTROL_PLANE_IP="10.0.3.2"


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

# Join Cluster
kubeadm join $CONTROL_PLANE_IP:6443 \
--token $TOKEN \
--discovery-token-ca-cert-hash sha256:$DISCOVERY_TOKEN

# Allow kubectl on worker
# mkdir -p ~/.kube
# scp dust@k8s-master-01:~/.kube/config config
# scp config dust@k8s-worker-01:~/.kube/config
# chmod 600 ~/.kube/config

# Verify
kubectl get nodes
