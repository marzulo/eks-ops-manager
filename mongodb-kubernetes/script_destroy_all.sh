#!/bin/bash
kubectl delete om ops-manager
kubectl delete mdbs rssearch
kubectl delete mdb rsbackup mongodb-sharded rssearch
kubectl delete mdbu --all
kubectl delete pod mailpit -n mailpit
kubectl delete svc mailpit-svc-ext -n mailpit
kubectl get secrets -o name | grep -v "adminusercredentials" | grep -v "opsmanagereks-db-om-password" | xargs kubectl delete
kubectl get configmap -o name | grep -v "kube-root-ca.crt" | grep -v "mongodb-enterprise-operator-telemetry" | xargs kubectl delete
kubectl get svc -o name | grep -v "operator-webhook" | xargs kubectl delete
kubectl get pvc -o name | grep -v "head-ops-manager-backup-daemon-0" | xargs kubectl delete
kubectl delete pvc head-ops-manager-backup-daemon-0 --grace-period=0 --force &
sleep 10
kubectl patch pvc head-ops-manager-backup-daemon-0 -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl delete pv --all --grace-period=0 --force
kubectl delete pod ops-manager-backup-daemon-0 --grace-period=0 --force

### If the pvc are stuck in Terminating state, you can try to remove the finalizers with kubectl patch pvc below
### kubectl get pvc my-pvc -n my-namespace -o json | jq .metadata.finalizers
### kubectl patch pvc  head-ops-manager-backup-daemon-0 -p '{"metadata":{"finalizers":null}}' --type=merge
### kubectl delete pod ops-manager-backup-daemon-0 --grace-period=0 --force
