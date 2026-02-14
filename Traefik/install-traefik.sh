#!/usr/bin/env bash
# Script to install and configure traefik Ingress Controller using Helm
# Written by Dustin Pollreis

# Send all output (stdout and stderr) to a log file in the same directory
# while still printing it to the console.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$script_dir/traefik-install.log"
printf "\n=== Traefik install started at %s ===\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

# Variables
TRAEFIK_VER="$1"
KUBECONFIG="/etc/kubernetes/admin.conf"

# Function to display usage information
usage() {
	echo "Usage: $0 [Traefik_Version]"
	echo "Example: $0 3.6"
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
	response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
	if [ "$response" != "200" ] && [ "$response" != "302" ]; then
		echo "Error: URL $url returned status $response"
		return 1
	fi
	return 0
}

# Function to apply Traefik configurations
apply_traefik_config() {
  local config_file="$1"
  if [ -z "$config_file" ]; then
    echo "Error: No Traefik configuration file provided to apply_traefik_config."
    exit 1
  fi
  if [ ! -f "$config_file" ]; then
    echo "Error: Traefik configuration file $config_file not found."
    exit 1
  fi

  echo "Applying Traefik configuration: $config_file"
  kubectl apply -f "$config_file"
}

# Function to install Traefik using Helm
install_traefik() {
	# Add repo and update
	helm repo add traefik https://traefik.github.io/charts
	helm repo update

	# Create namespace if needed
	kubectl create namespace traefik || true

	# Apply CRDs from upstream (verify URL first)
	crd_url="https://raw.githubusercontent.com/traefik/traefik/v3.6/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml"
	if verify_url "$crd_url"; then
		kubectl apply -f "$crd_url"
	else
		echo "CRD URL not reachable: $crd_url"
		exit 1
	fi

	# Install/upgrade Traefik via Helm
	if [ -f traefik-deployment.yaml ]; then
		helm upgrade --install traefik traefik/traefik --namespace traefik -f traefik-deployment.yaml
}

# Function to perform post-installation checks and display Traefik resources
post_install() {
	echo "Traefik resources (namespace: traefik):"
	kubectl -n traefik get all,secret,middleware,ingressroute || true

	echo "Traefik LoadBalancer external IP:"
	kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || true
	echo
}

main() {
	check_kubeconfig
    apply_traefik_config traefik-dashboard-secret.yaml
    apply_traefik_config traefik-dashboard-middleware.yaml
    apply_traefik_config traefik-dashboard-ingress.yaml
    apply_traefik_config traefik-dashboard-ip-allowlist.yaml
    sleep 10
	install_traefik
	sleep 40
	post_install
}

# Execute
main "$@"