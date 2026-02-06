#!/usr/bin/env bash
# Script to install and configure Helm for Kubernetes
# Written by Dustin Pollreis

# Update the package index
echo "Updating package index..."
apt-get update -y

# Install prerequisites
echo "Installing prerequisites (curl, apt-transport-https, gpg)..."
apt-get install -y curl gpg apt-transport-https

# Add the Helm signing key
echo "Adding Helm signing key..."
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null

# Add Helm repository
echo "Adding Helm repository..."
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list

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
