#!/bin/bash

# Define local storage directory
LOCAL_STORAGE_DIR="/home/scott/Projects/TAK/kube/local-storage"

# Create the local storage directory if it doesn't exist
if [ ! -d "$LOCAL_STORAGE_DIR" ]; then
    mkdir -p $LOCAL_STORAGE_DIR
    echo "Created local storage directory: $LOCAL_STORAGE_DIR"
else
    echo "Local storage directory already exists: $LOCAL_STORAGE_DIR"
fi

# Apply Persistent Volume and Persistent Volume Claim
kubectl apply -f deployment.yaml

# Verify PV and PVC status
kubectl get pv
kubectl get pvc

echo "Local Kubernetes PV & PVC setup completed successfully."
