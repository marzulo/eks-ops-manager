#!/bin/bash
echo "Configuring kubectl"
aws eks update-kubeconfig --region eu-west-1 --name eksopsmanager --profile tsteam
#export KUBECONFIG=~/.kube/config
echo "Rollout MCK1.2.0"
kubectl apply -f mongodb-init.yaml
kubectl config set-context $(kubectl config current-context) --namespace=mongodb
kubectl apply -f mongodb-storageclass-efs.yaml
kubectl apply -f mongodb-kubernetes120.yaml
kubectl apply -f crds120.yaml
kubectl apply -f ../mailpit/mailpit-static.yaml
kubectl apply -f ../mailpit/mailpit-loadbalancer.yaml
echo "Wait 1 minutes to leave the Operator stabilize"
sleep 60
kubectl get pods -A
kubectl describe deployments mongodb-kubernetes-operator -n mongodb
mailpiturl=`kubectl get svc mailpit-svc-ext -n mailpit -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
echo "Mailpit Web UI URL: http://${mailpiturl}:8025"
echo "TLS Create ConfigMap for Custom CA"
kubectl create secret tls om-ops-manager-cert --cert=tls/RS-test-serverom.crt --key=tls/RS-test-server.key
kubectl create secret tls appdb-ops-manager-db-cert --cert=tls/RS-test-server1.crt --key=tls/RS-test-server.key
kubectl create configmap ca-issuer --from-file=ca-pem=tls/test-CA.pem --from-file=mms-ca.crt=tls/mms-ca.crt
echo "Deploying OM - No Backup"
kubectl apply -f mongodb-om-tls-nobackup.yaml
echo "Wait 12 minutes at least to create the Load Balancer"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "Deploying Service Loadbalancer for OM"
kubectl apply -f mongodb-loadbalancer-om.yaml
sleep 60
kubectl get svc
sleep 60
kubectl get svc
sleep 60
kubectl get svc
echo "Configuring RS for Backup Configuration"
kubectl create secret tls bkp-rsbackup-cert --cert=tls/RS-rsbackup.crt --key=tls/RS-test-server.key
kubectl create secret tls bkp-rsbackup-agent-certs --cert=tls/RS-rsbkpagent.crt --key=tls/RS-test-server.key
kubectl create configmap custom-ca --from-file=ca-pem="tls/mms-ca.crt"
kubectl create secret tls bkp-rsbackup-clusterfile --cert=tls/RS-rsbackup.crt --key=tls/RS-test-server.key

### config the project configmap on ops manager and update mongodb-configmap-rsbackup.yaml
## Create a project rsbackup and organization api key on om
## When creating the new API Key, add the vpc_cidr as Access List Entry
## The secret for organization-secret in the stringData must have as fields publicKey and privateKey instead of user and publicApiKey
## In the configMap for the Replica set both variables (with ')):
##   - tlsRequireValidMMSServerCertificates: 'false'
##   - sslRequireValidMMSServerCertificates: 'false'

### IF LOCAL uses this command: lbsvcurl="127.0.0.1"
echo "Configuring Configmap for rsbackup"
lbsvcurl=`kubectl get svc ops-manager-svc-ext -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
omurl="https://${lbsvcurl}:8443/api/public/v1.0/orgs/"
publicKey=`kubectl get secret mongodb-ops-manager-admin-key -o jsonpath='{.data}' | jq -r '.publicKey' | base64 -d -i`
privateKey=`kubectl get secret mongodb-ops-manager-admin-key -o jsonpath='{.data}' | jq -r '.privateKey' | base64 -d -i`
password="${publicKey}:${privateKey}"
orgid=`curl --user $password --digest --header 'Accept: application/json' --request GET $omurl --insecure | jq -r '.results[0].id'`
sed -i "/  orgId:/c\  orgId: ${orgid}" mongodb-configmap-rsbackup.yaml
sed -i "/  publicKey:/c\  publicKey: ${publicKey}" mongodb-configmap-rsbackup.yaml
sed -i "/  privateKey:/c\  privateKey: ${privateKey}" mongodb-configmap-rsbackup.yaml
sed -i "/  orgId:/c\  orgId: ${orgid}" mongodb-configmap-sharded.yaml
echo "Applying Configmap for rsbackup"
kubectl apply -f mongodb-configmap-rsbackup.yaml
echo "Rollout rsbackup"
kubectl apply -f mongodb-rsbackupcreation.yaml
echo "Wait 8 minutes at least to create the Load Balancer for rsbackup"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "#################################################"
sleep 60
kubectl get pods -A
echo "Create Backup SCRAM user"
kubectl apply -f mongodb-backupuser-rsbackup.yaml
echo "Deploying Service Loadbalancer for rsbackup"
kubectl apply -f mongodb-loadbalancer-rs.yaml
sleep 60
kubectl get svc
sleep 60
kubectl get svc
echo "Ready to enable backup on OM"
### IF LOCAL uses this command: lbrssvcurl="127.0.0.1"
lbrssvcurl=`kubectl get svc rsbackup-svc-ext -o json | jq -r '.status.loadBalancer.ingress[0].hostname'`
mongoshurl="mongodb://backupuser:mongod123XMONGOD123x@${lbrssvcurl}:27017/?directConnection=true&tls=true&tlsCAFile=tls%2Ftest-CA.pem&tlsCertificateKeyFile=tls%2Ftest-rsbackup.pem&tlsAllowInvalidCertificates=true&replicaSet=rsbackup"
#mongoshurl="mongodb://backupuser:mongod123XMONGOD123x@rsbackup-0.rsbackup-svc.mongodb.svc.cluster.local:27017,rsbackup-1.rsbackup-svc.mongodb.svc.cluster.local:27017,rsbackup-2.rsbackup-svc.mongodb.svc.cluster.local:27017/?tls=true&tlsCAFile=%2Fvar%2Flib%2Fmongodb-automation%2Fsecrets%2Fca%2Fca-pem&tlsCertificateKeyFile=%2Fvar%2Flib%2Fmongodb-automation%2Fsecrets%2Fcerts%2F4YC56MIGOP3NPFN5S4OMSJ3HEESFCKY7O2DJ7EQUVHXHBAIWY2VA&tlsAllowInvalidCertificates=true&replicaSet=rsbackup"

# Need to validate how to allow SCRAM too
# mongoshurl="mongodb://backupuser:mongod123XMONGOD123x@${lbrssvcurl}:27017/?directConnection=true&authMechanism=SCRAM-SHA-256&authSource=admin&replicaSet=rsbackup"
# mongosh -u backupuser -p mongod123XMONGOD123x --host $lbrssvcurl --port 27017 --tls --tlsCAFile tls/test-CA.pem --tlsCertificateKeyFile tls/test-rsbackup.pem --tlsAllowInvalidCertificates
echo "String to connect into rsbackup"
echo $mongoshurl
echo "Enabling Backup on OM"
kubectl apply -f mongodb-om-tls-backup.yaml
kubectl get pods
echo "Finish"

#mongoshurlsharded="mongodb://backupusergreen:mongod123XMONGOD123x@af94e176776fc41d1a2c9c304be67fb6-2081289291.eu-west-1.elb.amazonaws.com:27017/?directConnection=true&authMechanism=SCRAM-SHA-256&authSource=admin"

