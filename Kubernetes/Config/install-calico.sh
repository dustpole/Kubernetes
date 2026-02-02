#!/usr/bin/env bash
setlocal

# Script to install and configure Calico CNI for Kubernetes
# Written by Dustin Pollreis

# Variables
set "CALICO_VER=%~1"

# Check for parameter
if "%~1"=="" (
    echo Error: No Calico version provided.
    echo Usage: install-calico.sh [Calico_Version]
    exit /b 1
)

# Install Calico CNI
kubectl apply -f \
"https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VER/manifests/calico.yaml"

# Verify
kubectl get pods -n kube-system | grep calico
# kubectl get pods -n calico-system

endlocal