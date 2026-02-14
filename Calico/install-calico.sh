#!/usr/bin/env bash
# Script to install and configure Calico CNI for Kubernetes
# Written by Dustin Pollreis

# Send all output (stdout and stderr) to a log file in the same directory
# while still printing it to the console.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$script_dir/calico-install.log"
printf "\n=== Calico install started at %s ===\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

# Variables
CALICO_VER="$1"
KUBECONFIG="/etc/kubernetes/admin.conf"
MANIFEST_URL="https://raw.githubusercontent.com/projectcalico/calico/v$CALICO_VER/manifests/calico.yaml"

# Function to display usage information
usage() {
  echo "Usage: $0 [Calico_Version]"
  echo "Example: $0 3.31.3"
  exit 1
}

# Function to check for kubeconfig file existence
check_kubeconfig() {
  if [ ! -f "$KUBECONFIG" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG."
    exit 1
  fi
}

# Function to verify that a URL is reachable and returns a successful status code
verify_url() {
  local url="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [ "$code" != "200" ] && [ "$code" != "302" ]; then
    echo "Error: URL check failed for $url (status=$code)."
    return 1
  fi
  return 0
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

  if ! verify_url "$MANIFEST_URL"; then
    echo "Error: Invalid Calico version or manifest not reachable: $CALICO_VER"
    exit 1
  fi

  echo "Applying Calico manifest from: $MANIFEST_URL"
  kubectl apply -f "$MANIFEST_URL"
}

# Function to display Calico pods and resources after installation
post_install() {
  echo "Calico pods and resources:"
  kubectl -n kube-system get pods -l k8s-app=calico-node || true
  kubectl -n kube-system get ds,svc,cm -l k8s-app=calico-node || true
}

main() {
  check_kubeconfig
  install_calico
  sleep 10
  post_install
}

# Execute the main function
main "$@"