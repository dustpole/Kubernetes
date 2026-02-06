#!/usr/bin/env bash
# Script to install and configure Calico CNI for Kubernetes
# Written by Dustin Pollreis

# Variables
CALICO_VER="$1"

# Set kube-config for this script's context
export KUBECONFIG=/etc/kubernetes/admin.conf

# Check for parameter
if [ -z "$CALICO_VER" ]; then
  echo "Error: No Calico version provided."
  echo "Usage: install-calico.sh [Calico_Version]"
  exit 1
fi

# Install Calico CNI
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VER/manifests/calico.yaml"