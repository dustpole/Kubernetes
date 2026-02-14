#!/usr/bin/env bash
# Script to install and configure MetalLB Load Balancer for Kubernetes
# Written by Dustin Pollreis

# Send all output (stdout and stderr) to a log file in the same directory
# while still printing it to the console.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$script_dir/metallb-install.log"
printf "\n=== MetalLB install started at %s ===\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

# Variables
MetalLB_VER="$1"
KUBECONFIG="/etc/kubernetes/admin.conf"

# Function to display usage information
usage() {
  echo "Usage: $0 [MetalLB_Version]"
  echo "Example: $0 0.15.3"
  exit 1
}

# Function to check for kubeconfig file existence
check_kubeconfig() {
  if [ ! -f "$KUBECONFIG" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG."
    exit 1
  fi
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

# Function to Create the secret key for memberlist protocol
create_memberlist_secret() {
  kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
}

# Function to Apply metallb configurations
apply_metallb_config() {
  local config_file="$1"
  if [ -z "$config_file" ]; then
    echo "Error: No MetalLB configuration file provided to apply_metallb_config."
    exit 1
  fi
  if [ ! -f "$config_file" ]; then
    echo "Error: MetalLB configuration file $config_file not found."
    exit 1
  fi

  echo "Applying MetalLB configuration: $config_file"
  kubectl apply -f "$config_file"
}

# Function to perform post-installation checks and display MetalLB resources
post_install() {
  # Check MetalLB pods
  echo "Checking MetalLB pods..."
  kubectl get pods -n metallb-system

  # Confirm the IP pool
  echo "Confirming MetalLB IP pools..."
  kubectl get ipaddresspools -n metallb-system
}

# Main script execution
main() {
  check_kubeconfig
  install_metallb
  sleep 10
  create_memberlist_secret
  sleep 20
  apply_metallb_config metallb-pool.yaml
  sleep 10
  apply_metallb_config metallb-l2-advertisement.yaml
  sleep 40
  post_install
}

# Execute the main function
main "$@"