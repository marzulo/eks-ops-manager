#!/bin/bash
## test CA key file
openssl genrsa -out CA-test-ca.key 4096
## CA certificate batch
openssl req -new -x509 -days 1826 -key CA-test-ca.key -out CA-test-ca.crt -config openssl-test-ca.cnf -batch
## private key for the intermediate certificate
openssl genrsa -out CA-test-ia.key 4096
## certificate signing request for the intermediate certificate
openssl req -new -key CA-test-ia.key -out CA-test-ia.csr -config openssl-test-ca.cnf -batch
## intermediate certificate
openssl x509 -sha256 -req -days 730 -in CA-test-ia.csr -CA CA-test-ca.crt -CAkey CA-test-ca.key -set_serial 01 -out CA-test-ia.crt -extfile openssl-test-ca.cnf -extensions v3_ca
## test CA PEM file 
cat CA-test-ia.crt CA-test-ca.crt > test-CA.pem

## key file
openssl genrsa -out RS-test-server.key 4096
## generating CSR to RS
openssl req -new -key RS-test-server.key -out RS-test-server1.csr -config openssl-test-rs1.cnf -batch
openssl req -new -key RS-test-server.key -out RS-test-serverom.csr -config openssl-test-om.cnf -batch
## generating CRT to RS
openssl x509 -sha256 -req -days 365 -in RS-test-server1.csr -CA CA-test-ia.crt -CAkey CA-test-ia.key -CAcreateserial -out RS-test-server1.crt -extfile openssl-test-rs1.cnf -extensions v3_req
openssl x509 -sha256 -req -days 365 -in RS-test-serverom.csr -CA CA-test-ia.crt -CAkey CA-test-ia.key -CAcreateserial -out RS-test-serverom.crt -extfile openssl-test-om.cnf -extensions v3_req
## generating PEM to RS
cat RS-test-server1.crt RS-test-server.key > test-RS.pem
cat RS-test-serverom.crt RS-test-server.key > test-OM.pem
## Adding mongodb CA
openssl s_client -showcerts -verify 2 -connect downloads.mongodb.com:443 -servername downloads.mongodb.com < /dev/null | awk '/BEGIN/,/END/{ if(/BEGIN/){a++}; out="cert"a".crt"; print >out}'
cat test-CA.pem cert2.crt cert3.crt  > mms-ca.crt

## To delete cleanup: rm *.crt *.csr *.key *.srl *.pem

## generating rsbackup certificates
openssl req -new -key RS-test-server.key -out RS-rsbackup.csr -config openssl-rsbackup.cnf -batch
openssl req -new -key RS-test-server.key -out RS-rsbkpagent.csr -config openssl-rsbkpagent.cnf -batch
openssl x509 -sha256 -req -days 365 -in RS-rsbackup.csr -CA CA-test-ia.crt -CAkey CA-test-ia.key -CAcreateserial -out RS-rsbackup.crt -extfile openssl-rsbackup.cnf -extensions v3_req
openssl x509 -sha256 -req -days 365 -in RS-rsbkpagent.csr -CA CA-test-ia.crt -CAkey CA-test-ia.key -CAcreateserial -out RS-rsbkpagent.crt -extfile openssl-rsbkpagent.cnf -extensions v3_req

cat RS-rsbackup.crt RS-test-server.key > test-rsbackup.pem
cat RS-rsbkpagent.crt RS-test-server.key > test-rsbkpagent.pem

## generating rssearch certificates
openssl req -new -key RS-test-server.key -out RS-rssearch.csr -config openssl-rssearch.cnf -batch
openssl req -new -key RS-test-server.key -out RS-rssearch-agent.csr -config openssl-rssearch-agent.cnf -batch
openssl x509 -sha256 -req -days 365 -in RS-rssearch.csr -CA CA-test-ia.crt -CAkey CA-test-ia.key -CAcreateserial -out RS-rssearch.crt -extfile openssl-rssearch.cnf -extensions v3_req
openssl x509 -sha256 -req -days 365 -in RS-rssearch-agent.csr -CA CA-test-ia.crt -CAkey CA-test-ia.key -CAcreateserial -out RS-rssearch-agent.crt -extfile openssl-rssearch-agent.cnf -extensions v3_req

cat RS-rssearch.crt RS-test-server.key > test-rssearch.pem
cat RS-rssearch-agent.crt RS-test-server.key > test-rssearch-agent.pem
