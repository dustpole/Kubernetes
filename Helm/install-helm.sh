#!/usr/bin/env bash
# Script to install Helm for Kubernetes on an Ubuntu Server.
# Written by Dustin Pollreis

# Send all output (stdout and stderr) to a log file in the same directory
# while still printing it to the console.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$script_dir/helm-install.log"
printf "\n=== Helm install started at %s ===\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

# Variables
HELM_KEY_URL="https://packages.buildkite.com/helm-linux/helm-debian/gpgkey"
HELM_REPO_BASE="https://packages.buildkite.com/helm-linux/helm-debian/any/"

# Function to display usage information
usage() {
	echo "Usage: $0"
	echo "Installs Helm on an Ubuntu server. Run as root or with sudo."
	exit 1
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

# Function to install prerequisites
install_prereqs() {
	echo "Updating package index..."
	apt-get update -y

	echo "Installing prerequisites (curl, gpg, apt-transport-https)..."
	apt-get install -y curl gpg apt-transport-https
}

# Function to add Helm GPG key and repository
add_key_and_repo() {
	echo "Checking Helm key and repository URLs..."
	verify_url "$HELM_KEY_URL" || return 1
	verify_url "$HELM_REPO_BASE" || return 1

	echo "Adding Helm signing key..."
	curl -fsSL "$HELM_KEY_URL" | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null

	echo "Adding Helm repository..."
	echo "deb [signed-by=/usr/share/keyrings/helm.gpg] ${HELM_REPO_BASE} any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list

	echo "Updating package index with Helm repository..."
	apt-get update -y
}

# Function to install Helm
install_helm() {
	echo "Installing Helm..."
	apt-get install -y helm

	echo "Verifying Helm installation..."
	helm version || true

	echo "Helm installation complete!"
}

main() {
	install_prereqs
	add_key_and_repo
	install_helm
}

# Execute
main "$@"
