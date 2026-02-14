#!/usr/bin/env bash
# Script to install and configure Calico CNI for Kubernetes
# Written by Dustin Pollreis

# Variables
CALICO_VER="$1"
KUBECONFIG="/etc/kubernetes/admin.conf"

# Function to display usage information
usage() {
  echo "Usage: $0 [Calico_Version]"
  echo "Example: $0 3.31.3"
  exit 1
}

# Function to install Calico CNI
install_calico() {
  if [ -z "$CALICO_VER" ]; then
    echo "Error: No Calico version provided."
    usage
  fi

  # Check if the version format is valid
  if [[ ! $CALICO_VER =~ ^[0-9.]+$ ]] || [ ${#CALICO_VER} -ge 10 ]; then
    echo "Error: Invalid Calico version format provided."
    usage
  fi

  # Check if the URL returns a successful status code
  response=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/projectcalico/calico/v$CALICO_VER/manifests/calico.yaml")
  if [ "$response" != "200" ] && [ "$response" != "302" ]; then
    echo "Error: Invalid Calico version provided."
    exit 1
  fi

  kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/v$CALICO_VER/manifests/calico.yaml"
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
  install_calico
}

# Execute the main function
main "$@"