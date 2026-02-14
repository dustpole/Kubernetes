#!/usr/bin/env bash
# Script to install and configure MetalLB Load Balancer for Kubernetes
# Written by Dustin Pollreis

# Variables
MetalLB_VER="$1"
KUBECONFIG="/etc/kubernetes/admin.conf"

# Function to display usage information
usage() {
  echo "Usage: $0 [MetalLB_Version]"
  echo "Example: $0 0.15.3"
  exit 1
}

# Function to install MetalLB (Layer 2 Mode)
install_metallb() {
  if [ -z "$MetalLB_VER" ]; then
    echo "Error: No MetalLB version provided."
    usage
  fi

  # Check if the version format is valid
  if [[ ! $MetalLB_VER =~ ^[0-9.]+$ ]] || [ ${#MetalLB_VER} -ge 10 ]; then
    echo "Error: Invalid MetalLB version format provided."
    usage
  fi

  # Check if the URL returns a successful status code
  response=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/metallb/metallb/v$MetalLB_VER/config/manifests/metallb-native.yaml")
  if [ "$response" != "200" ] && [ "$response" != "302" ]; then
    echo "Error: Invalid MetalLB version provided."
    exit 1
  fi

  kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/v$MetalLB_VER/config/manifests/metallb-native.yaml"
}

# Function to check for kubeconfig file existence
check_kubeconfig() {
  if [ ! -f "$KUBECONFIG" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG."
    exit 1
  fi
}

# Main script execution
main() {
  check_kubeconfig
  install_metallb
}

# Execute the main function
main "$@"