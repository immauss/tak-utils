#!/bin/bash

# Define local storage directory
LOCAL_STORAGE_DIR="/Users/scott/Projects/tak-utils/kube/local-storage"

# Create the local storage directory if it doesn't exist
if [ ! -d "$LOCAL_STORAGE_DIR" ]; then
    mkdir -p $LOCAL_STORAGE_DIR/tak-db
    mkdir -p $LOCAL_STORAGE_DIR/tak-certs
    mkdir -p $LOCAL_STORAGE_DIR/tak-configs
    echo "Created local storage directory: $LOCAL_STORAGE_DIR"
    cp /Users/scott/Projects/tak-utils/build/configs/*.xml $LOCAL_STORAGE_DIR/tak-configs
else
    echo "Local storage directory already exists: $LOCAL_STORAGE_DIR"
fi

# Apply Persistent Volume and Persistent Volume Claim
TMP_YAML=$(mktemp)
sed -e "s|STORAGEPATH|$LOCAL_STORAGE_DIR|" storage.yaml > $TMP_YAML
kubectl apply -f $TMP_YAML
rm $TMP_YAML

# Verify PV and PVC status
kubectl get pv -n tak 
kubectl get pvc -n tak

echo "Local Kubernetes PV & PVC setup completed successfully."
