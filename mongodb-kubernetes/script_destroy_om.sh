#!/bin/bash
kubectl delete mdb mongodb-sharded
kubectl delete mdb rsbackup
kubectl delete om ops-manager
kubectl delete pod mailpit -n mailpit
kubectl delete svc mailpit-svc-ext -n mailpit
kubectl delete secrets --all
kubectl delete configmap ca-issuer custom-ca mongodb-sharded-configmap mongodb-sharded-state ops-manager-db-automation-config-version ops-manager-db-cluster-mapping ops-manager-db-member-spec ops-manager-db-monitoring-automation-config-version ops-manager-db-project-id ops-manager-db-state rsbackup
kubectl delete svc --all
kubectl patch pvc head-ops-manager-backup-daemon-0 -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl delete pvc --all --grace-period=0 --force
kubectl delete pv --all --grace-period=0 --force
kubectl delete pod ops-manager-backup-daemon-0 --grace-period=0 --force

### If the pvc are stuck in Terminating state, you can try to remove the finalizers with kubectl patch pvc below
### kubectl get pvc my-pvc -n my-namespace -o json | jq .metadata.finalizers
### kubectl patch pvc  head-ops-manager-backup-daemon-0 -p '{"metadata":{"finalizers":null}}' --type=merge
### kubectl delete pod ops-manager-backup-daemon-0 --grace-period=0 --force
