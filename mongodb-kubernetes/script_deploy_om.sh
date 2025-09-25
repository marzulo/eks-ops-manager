#!/bin/bash

# Exit immediately if any command fails
#set -e

# Function to print usage
usage() {
  echo "Usage: $0 <AWS_REGION> <EKS_CLUSTER_NAME> <PROFILE>"
  exit 1
}

# Check that 3 parameters are provided
if [ $# -ne 3 ]; then
  echo "Error: Exactly 3 parameters are required."
  usage
  exit 1
fi

param1="$1"
param2="$2"
param3="$3"

# Check cluster name have a valid format
if [[ ! "$param2" =~ ^[a-zA-Z0-9]+$ ]]; then
  echo "Error: param2 ('$param2') must be alphanumeric."
  usage
  exit 1
fi

echo "Starting deployment script with parameters:"
echo "AWS Region: $param1"
echo "EKS Cluster Name: $param2"
echo "AWS Profile: $param3"

echo "Configuring kubectl"
aws eks update-kubeconfig --region $param1 --name $param2 --profile $param3
#export KUBECONFIG=~/.kube/config
echo "Rollout MCK1.4.0"
kubectl apply -f mongodb-init.yaml
kubectl config set-context $(kubectl config current-context) --namespace=mongodb
kubectl apply -f mongodb-storageclass-efs.yaml
kubectl apply -f crds140.yaml
kubectl apply -f mongodb-kubernetes140.yaml
kubectl apply -f ../mailpit/mailpit-static.yaml
kubectl apply -f ../mailpit/mailpit-loadbalancer.yaml
echo "Wait 1 minutes to leave the Operator stabilize"
sleep 60
kubectl get pods -A
#kubectl describe deployments mongodb-kubernetes-operator -n mongodb
mailpiturl=`kubectl get svc mailpit-svc-ext -n mailpit -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
echo "Mailpit Web UI URL: http://${mailpiturl}:8025"
echo "TLS Create ConfigMap for Custom CA"
kubectl create secret tls om-ops-manager-cert --cert=tls/RS-test-serverom.crt --key=tls/RS-test-server.key --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls appdb-ops-manager-db-cert --cert=tls/RS-test-server1.crt --key=tls/RS-test-server.key --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap ca-issuer --from-file=ca-pem=tls/test-CA.pem --from-file=mms-ca.crt=tls/mms-ca.crt --dry-run=client -o yaml | kubectl apply -f -
echo "Deploying OM - No Backup"
kubectl apply -f mongodb-om-tls-nobackup.yaml
sleep 30
echo "Wait some minutes to create the Load Balancer"
kubectl wait --for=condition=Ready pod/ops-manager-db-0 --timeout=300s
if [ $? -eq 0 ]; then
  sleep 30
  kubectl wait --for=condition=Ready pod/ops-manager-db-1 --timeout=300s
  if [ $? -eq 0 ]; then
    sleep 30
    kubectl wait --for=condition=Ready pod/ops-manager-db-2 --timeout=300s
    sleep 120
    if [ $? -eq 0 ]; then
      kubectl wait --for=condition=Ready pod/ops-manager-0 --timeout=450s
      if [ $? -eq 0 ]; then
        echo "om-tls-nobackup deployed"
      else
         echo "om-tls-nobackup not deployed yet waiting a little bit more"
         kubectl get pods -A
         #kubectl describe om ops-manager
         #kubectl describe pod ops-manager-0
         kubectl wait --for=condition=Ready pod/ops-manager-0 --timeout=450s
         if [ $? -eq 0 ]; then
           echo "om-tls-nobackup deployed"
         else
          echo "om-tls-nobackup not deployed - unknown error"
          exit 1
         fi
      fi
    else
      echo "ops-manager-db-2 took too much to be Ready. Exiting..."
      kubectl get pods -A
      #kubectl describe om ops-manager
      #kubectl describe pod ops-manager-db-2
      exit 1
    fi
  else
    echo "ops-manager-db-1 took too much to be Ready. Exiting..."
    kubectl get pods -A
    #kubectl describe om ops-manager
    #kubectl describe pod ops-manager-db-1
    exit 1
  fi
else
  echo "ops-manager-db-0 took too much to be Ready. Exiting..."
  kubectl get pods -A
  #kubectl describe om ops-manager
  #kubectl describe pod ops-manager-db-0
  exit 1
fi
kubectl get pods -A
kubectl get svc -A
#echo "Deploying Service Loadbalancer for OM"
#kubectl apply -f mongodb-loadbalancer-om.yaml
echo "Configuring RS for Backup and Search Configuration"
kubectl create secret tls bkp-rsbackup-cert --cert=tls/RS-rsbackup.crt --key=tls/RS-test-server.key --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls bkp-rsbackup-agent-certs --cert=tls/RS-rsbkpagent.crt --key=tls/RS-test-server.key --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls bkp-rsbackup-clusterfile --cert=tls/RS-rsbackup.crt --key=tls/RS-test-server.key --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls search-rssearch-cert --cert=tls/RS-rssearch.crt --key=tls/RS-test-server.key --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls search-rssearch-agent-certs --cert=tls/RS-rssearch-agent.crt --key=tls/RS-test-server.key --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls search-rssearch-clusterfile --cert=tls/RS-rssearch.crt --key=tls/RS-test-server.key --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap custom-ca --from-file=ca-pem="tls/mms-ca.crt" --dry-run=client -o yaml | kubectl apply -f -

### config the project configmap on ops manager and update mongodb-configmap-rsbackup.yaml
## Create a project rsbackup and organization api key on om
## When creating the new API Key, add the vpc_cidr as Access List Entry
## The secret for organization-secret in the stringData must have as fields publicKey and privateKey instead of user and publicApiKey
## In the configMap for the Replica set both variables (with ')):
##   - tlsRequireValidMMSServerCertificates: 'false'
##   - sslRequireValidMMSServerCertificates: 'false'

### IF LOCAL uses this command: lbsvcurl="127.0.0.1"
echo "Configuring Configmap for rsbackup sharded and rssearch"
lbsvcurl=`kubectl get svc ops-manager-svc-ext -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
echo "Ops Manager UI URL: https://${lbsvcurl}:8443"
omurl="https://${lbsvcurl}:8443/api/public/v1.0/orgs/"
publicKey=`kubectl get secret mongodb-ops-manager-admin-key -o jsonpath='{.data}' | jq -r '.publicKey' | base64 -d -i`
privateKey=`kubectl get secret mongodb-ops-manager-admin-key -o jsonpath='{.data}' | jq -r '.privateKey' | base64 -d -i`
password="${publicKey}:${privateKey}"
orgid=`curl --user $password --digest --header 'Accept: application/json' --request GET $omurl --insecure | jq -r '.results[0].id'`
sed -i "/  orgId:/c\  orgId: ${orgid}" mongodb-configmap-rsbackup.yaml
sed -i "/  publicKey:/c\  publicKey: ${publicKey}" mongodb-configmap-rsbackup.yaml
sed -i "/  privateKey:/c\  privateKey: ${privateKey}" mongodb-configmap-rsbackup.yaml
sed -i "/  orgId:/c\  orgId: ${orgid}" mongodb-configmap-sharded.yaml
sed -i "/  orgId:/c\  orgId: ${orgid}" mongodb-configmap-rssearch.yaml
echo "Applying Configmap for rsbackup"
kubectl apply -f mongodb-configmap-rsbackup.yaml
echo "Applying Configmap for sharded"
kubectl apply -f mongodb-configmap-sharded.yaml
echo "Applying Configmap for rssearch"
kubectl apply -f mongodb-configmap-rssearch.yaml
echo "Rollout rsbackup"
kubectl apply -f mongodb-rsbackupcreation.yaml
sleep 120
statusstsrs=`kubectl get sts rsbackup -o json | jq -r '.status.availableReplicas'`
if [ $statusstsrs -eq 3 ]; then
  echo "rsbackup deployed"
else
  echo "rsbackup not deployed yet waiting a little bit more: $statusstsrs availableReplicas"
  kubectl get pods -A
  #kubectl describe mdb rsbackup
  #kubectl describe pod rsbackup-0
  #kubectl describe sts rsbackup
  sleep 120
  statusstsrs=`kubectl get sts rsbackup -o json | jq -r '.status.availableReplicas'`
  if [ $statusstsrs -eq 3 ]; then
    echo "rsbackup deployed"
  else
    echo "rsbackup not deployed - unknown error: $statusstsrs availableReplicas"
    exit 1
  fi
fi
kubectl get pods -A
echo "Create Backup SCRAM user"
kubectl apply -f mongodb-backupuser-rsbackup.yaml

echo "Enabling Backup on OM"
kubectl apply -f mongodb-om-tls-backup.yaml
sleep 30
kubectl wait --for=condition=Ready pod/ops-manager-backup-daemon-0 --timeout=300s
if [ $? -eq 0 ]; then
  echo "ops-manager-backup-daemon-0 deployed"
else
  echo "ops-manager-backup-daemon-0 not deployed yet waiting a little bit more"
  kubectl get pods -A
  #kubectl describe om ops-manager
  #kubectl describe pod ops-manager-backup-daemon-0
  sleep 30
  kubectl wait --for=condition=Ready pod/ops-manager-backup-daemon-0 --timeout=60s
  if [ $? -eq 0 ]; then
    echo "ops-manager-backup-daemon-0 deployed"
  else
    echo "ops-manager-backup-daemon-0 not deployed - unknown error"
    exit 1
  fi
fi
kubectl get pods
echo "Finish.
echo "Type 'kubectl apply -f mongodb-sharded-creation.yaml' to deploy the sharded cluster"
echo "Type './script_deploy_search.sh $param1 $param2 $param3' to deploy Replica Set with Search"

### echo "Getting Load Balancer URL for sharded cluster"
### lbrssvcurl=`kubectl get svc mongodb-sharded-mongos-0-svc-external -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
### shardurl="mongodb://backupuser:mongod123XMONGOD123x@$lbrssvcurl:27017/"
### echo "mongosh \"$mongoshurl\""
