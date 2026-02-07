#!/usr/bin/env bash

# Script to install and configure MetalLB Load Balancer for Kubernetes
# Written by Dustin Pollreis

# Variables
MetalLB_VER="$1"

# Set kube-config for this script's context
export KUBECONFIG=/etc/kubernetes/admin.conf

# Check for parameter
if [ -z "$MetalLB_VER" ]; then
  echo "Error: No MetalLB version provided."
  echo "Usage: install-metalLB.sh [MetalLB_Version]"
  exit 1
fi

# Install MetalLB (Layer 2 Mode)
kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/$MetalLB_VER/config/manifests/metallb-native.yaml"