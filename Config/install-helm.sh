#!/usr/bin/env bash
# Script to install Helm for Kubernetes on an Ubuntu Server.
# Written by Dustin Pollreis

# Variables
HELM_KEY_URL="https://packages.buildkite.com/helm-linux/helm-debian/gpgkey"
HELM_REPO_BASE="https://packages.buildkite.com/helm-linux/helm-debian/any/"

# Check if the URL returns a successful status code
check_url() {
	local url="$1"
	local code
	code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
	if [ "$code" != "200" ] && [ "$code" != "302" ]; then
		echo "Error: URL check failed for $url (status=$code)."
		exit 1
	fi
}

# Update the package index
echo "Updating package index..."
apt-get update -y

# Install prerequisites
echo "Installing prerequisites (curl, gpg, apt-transport-https)..."
apt-get install -y curl gpg apt-transport-https

# Validate remote resources before using them
echo "Checking Helm key and repository URLs..."
check_url "$HELM_KEY_URL"
check_url "$HELM_REPO_BASE"

# Add the Helm signing key
echo "Adding Helm signing key..."
curl -fsSL "$HELM_KEY_URL" | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null

# Add Helm repository
echo "Adding Helm repository..."
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] ${HELM_REPO_BASE} any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list

# Update the package index again to include Helm
echo "Updating package index with Helm repository..."
apt-get update -y

# Install Helm
echo "Installing Helm..."
apt-get install -y helm

# Verify the installation
echo "Verifying Helm installation..."
helm version

echo "Helm installation complete!"
