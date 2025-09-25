#!/bin/bash
kubectl delete mdbs rssearch
kubectl delete mdb rssearch
kubectl delete mdbu rssearch-admin rssearch-user search-sync-source-user 
kubectl delete secrets rssearch-keyfile rssearch-rssearch-admin-admin rssearch-rssearch-user-admin rssearch-search-sync-source-password rssearch-search-sync-source-user-admin  search-rssearch-cert-pem
kubectl get svc -o name | grep "rssearch" | xargs kubectl delete
kubectl get pvc -o name | grep "rssearch" | xargs kubectl delete
kubectl get pv --no-headers | awk '$5=="Released"{print $1}' | xargs kubectl delete pv
