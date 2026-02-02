#!/usr/bin/env bash
# Script to install and configure traefik Ingress Controller using Helm
# Written by Dustin Pollreis

# Instal Helm
apt install helm

# Add Traefik repo
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Create dedicated namespace
kubectl create namespace traefik

# Install Traefik using Helm
helm upgrade traefik traefik/traefik \
  --namespace traefik \
  --values values.yaml

# Watch the pods until they are running
kubectl -n traefik get pods -l app.kubernetes.io/name=traefik -o wide -w

# Verify the service
kubectl -n traefik get svc traefik


# Verify installation
kubectl get all -n traefik

# Get the external IP of the Traefik LoadBalancer
kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Test access to Traefik dashboard
kubectl -n traefik port-forward svc/traefik 9000:9000
# Open http://localhost:9000/dashboard/ (trailing slash required)