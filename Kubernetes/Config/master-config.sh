#!/usr/bin/env bash
# Script to install and configure a Kubernetes Control Plane using k8s
# Written by Dustin Pollreis

# Variables

# Install basic tools
sudo apt install iputils-ping dnsutils htop tree git

# Set timezone
sudo timedatectl set-timezone America/Chicago

# Verify
timedatectl

# Remove swap
sudo swapoff -a
sudo sed -i '/\s\+swap\s\+/ s/^/# /' /etc/fstab

# Kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl Networking
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1 
net.bridge.bridge-nf-call-ip6tables = 1 
net.ipv4.ip_forward                 = 1 
EOF

sudo sysctl --system

# Disable Firewall
sudo ufw disable

# Update package index and install containerd
sudo apt update && sudo apt install -y containerd

# Generate default config
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Edit the config to enable systemd cgroups
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart and enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Install prerequisites
sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl gpg

# Download the GPG key for the repo and dearmor it 
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes repo entry
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Refresh package list
sudo apt update

# Install kubernetes packages
sudo apt update && sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo kubeadm init --config init-config.yaml --upload-certs

# Configure kubectl
mkdir -p $HOME/.kube 
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config 
sudo chown $$ (id -u): $$(id -g) $HOME/.kube/config

# Join Cluster (On Worker)
sudo kubeadm join 10.0.3.2:6443 \
--token uvfgky.y4ysivfcqiqa9q9j \
--discovery-token-ca-cert-hash sha256:4ad689c8abc82ee3e8d23284e6ccdc4b60ff43c1d0ca7bce301363ae2143c71b

# Allow kubectl on worker
mkdir -p ~/.kube
scp dust@k8s-master-01:~/.kube/config config
scp config dust@k8s-worker-01:~/.kube/config
chmod 600 ~/.kube/config

# Verify
kubectl get nodes

# Install Calico CNI
kubectl apply -f \
https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

# Verify
kubectl get pods -n kube-system | grep calico
# kubectl get pods -n calico-system

# Install MetalLB (Layer 2 Mode)
kubectl apply -f \
https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml

# Verify
kubectl get pods -n metallb-system

# Apply metallb config
kubectl apply -f ~/.kube/metallb.yaml

# Verify MetalLB is working
# Check MetalLB pods
kubectl get pods -n metallb-system

# Confirm the IP pool
kubectl get ipaddresspools -n metallb-system


# Test with a LoadBalancer service
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --type=LoadBalancer --port=80

# Verify
kubectl get svc nginx
