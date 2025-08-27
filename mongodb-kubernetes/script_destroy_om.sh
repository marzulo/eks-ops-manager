#!/bin/bash
kubectl delete mdb mongodb-sharded
kubectl delete mdb rsbackup
kubectl delete om ops-manager
kubectl delete svc --all
kubectl delete svc mailpit-svc-ext -n mailpit
