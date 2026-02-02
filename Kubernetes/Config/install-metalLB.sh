#!/usr/bin/env bash

# Script to install and configure MetalLB Load Balancer for Kubernetes
# Written by Dustin Pollreis

# Variables
MetalLB_VER="$1"

# Check for parameter
if [ -z "$MetalLB_VER" ]; then
  echo "Error: No MetalLB version provided."
  echo "Usage: install-metalLB.sh [MetalLB_Version]"
  exit 1
fi


# Install MetalLB (Layer 2 Mode)
kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/$MetalLB_VER/config/manifests/metallb-native.yaml"

# Verify
kubectl get pods -n metallb-system

# Copy metallb config file
cp ./metallb.yaml ~/.kube/metallb.yaml

# Apply metallb config
kubectl apply -f ~/.kube/metallb.yaml

# Verify MetalLB is working
# Check MetalLB pods
kubectl get pods -n metallb-system

# Confirm the IP pool
kubectl get ipaddresspools -n metallb-system