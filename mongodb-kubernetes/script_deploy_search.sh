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

echo "Starting deployment script for Search node with parameters:"
echo "AWS Region: $param1"
echo "EKS Cluster Name: $param2"
echo "AWS Profile: $param3"

echo "Configuring kubectl"
aws eks update-kubeconfig --region $param1 --name $param2 --profile $param3
#export KUBECONFIG=~/.kube/config
echo "Rollout rssearch"
kubectl config set-context $(kubectl config current-context) --namespace=mongodb

## remove connectivity section from the file
sed -i '/^[[:space:]]*connectivity:/,/^[^[:space:]]/d' mongodb-rssearch-creation.yaml

kubectl apply -f mongodb-rssearch-creation.yaml
sleep 120
statusstsrs=`kubectl get sts rssearch -o json | jq -r '.status.availableReplicas'`
if [ $statusstsrs -eq 3 ]; then
  echo "rssearch deployed"
else
  echo "rssearch not deployed yet waiting a little bit more: $statusstsrs availableReplicas"
  kubectl get pods -A
  sleep 120
  statusstsrs=`kubectl get sts rssearch -o json | jq -r '.status.availableReplicas'`
  if [ $statusstsrs -eq 3 ]; then
    echo "rssearch deployed"
  else
    echo "rssearch not deployed - unknown error: $statusstsrs availableReplicas"
    exit 1
  fi
fi
kubectl get pods -A
echo "Create Search SCRAM user"
kubectl apply -f mongodb-searchuser-rssearch.yaml

### mongoshurl="mongodb://rssearch-admin:mongod123XMONGOD123x@${lbrssvcurl}:27017/?directConnection=true&tls=true&tlsCAFile=tls%2Ftest-CA.pem&tlsCertificateKeyFile=tls%2Ftest-rsbackup.pem&tlsAllowInvalidCertificates=true&replicaSet=rsbackup"
### mongoshurl="mongodb://rssearch-admin:mongod123XMONGOD123x@rssearch-0.rssearch-svc.mongodb.svc.cluster.local:27017,rssearch-1.rssearch-svc.mongodb.svc.cluster.local:27017,rssearch-2.rssearch-svc.mongodb.svc.cluster.local:27017/?tls=true&tlsCAFile=%2Fmongodb-automation%2Ftls%2Fca%2Fca-pem&tlsCertificateKeyFile=%2Fmongodb-automation%2Fcluster-auth%2F7SNDAA7I5IDKW3BQOE2ZX54H6YYOSAKI6FOF6FYMVQCN7ZBBWWQQ&tlsAllowInvalidCertificates=true&replicaSet=rssearch"
### mongosh -u rssearch-admin -p mongod123XMONGOD123x --host $lbsvcurl0 --port 27017 --tls --tlsCAFile tls/test-CA.pem --tlsCertificateKeyFile tls/test-rsbackup.pem --tlsAllowInvalidCertificates
### echo "String to connect into rsbackup"
### echo $mongoshurl

echo "Applying replicaSetHorizons to rssearch"
lbsvcurl0=`kubectl get svc rssearch-0-svc-external -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
lbsvcurl1=`kubectl get svc rssearch-1-svc-external -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
lbsvcurl2=`kubectl get svc rssearch-2-svc-external -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`

cat <<EOF >> mongodb-rssearch-creation.yaml
  connectivity:
    replicaSetHorizons:
    - "rssearch-svc-external": "$lbsvcurl0:27017"
    - "rssearch-svc-external": "$lbsvcurl1:27017"
    - "rssearch-svc-external": "$lbsvcurl2:27017"
EOF
kubectl apply -f mongodb-rssearch-creation.yaml

mongoshurl="mongodb://rssearch-admin:mongod123XMONGOD123x@$lbsvcurl0:27017,$lbsvcurl1:27017,$lbsvcurl2:27017/?tls=true&tlsCAFile=tls/test-CA.pem&tlsCertificateKeyFile=tls/test-rsbackup.pem&tlsAllowInvalidCertificates=true&replicaSet=rssearch"

kubectl get pods
kubectl get svc

echo "Type to connect:"
echo "mongosh -u rssearch-admin -p mongod123XMONGOD123x --host $lbsvcurl0 --port 27017 --tls --tlsCAFile tls/test-CA.pem --tlsCertificateKeyFile tls/test-rsbackup.pem --tlsAllowInvalidCertificates"
echo "or"
echo "mongosh \"$mongoshurl\""

echo "Deploying Search service"

kubectl apply -f mongodb-search.yaml
sleep 120
kubectl wait --for=condition=Ready pod/rssearch-search-0 --timeout=300s

echo "Finish."
