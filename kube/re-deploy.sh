#!/bin/bash
kubectl delete -f deployment.yaml -f storage.yaml
rm -rf local-storage
sleep 1
./create-pvc.sh
kubectl apply -f deployment.yaml
sleep 3
kubectl -n tak get pods 
sleep 3
kubectl -n tak get pods 
