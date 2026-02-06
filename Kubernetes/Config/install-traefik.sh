#!/usr/bin/env bash
# Script to install and configure traefik Ingress Controller using Helm
# Written by Dustin Pollreis

# Add Traefik repo
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Create dedicated namespace
kubectl create namespace traefik

# Apply Traefik CRDs
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.6/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml

# htpasswd -nb admin your-strong-password if needed for dashboard auth
# Apply dashboard secret for basic auth
kubectl apply -f dashboard-secret.yaml

# Apply Traefik dashboard middleware
kubectl apply -f dashboard-middleware.yaml

# Apply Traefik dashboard Ingress
kubectl apply -f dashboard-ingress.yaml

# Install Traefik using Helm
helm upgrade --install traefik traefik/traefik --namespace traefik -f traefik-deployment.yaml

# Restart Traefik DaemonSet to apply changes 
# kubectl rollout restart ds/traefik -n traefik