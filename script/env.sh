#!/bin/bash

# Path to configtxlator tool
export CONFIGTXLATOR="../../clara/bin/configtxlator"

# Cluster configuration files
export CONFIG_CLUSTER1="/Users/mwojciechowski/.kube/hlf-ams-kubeconfig.yaml"
export CONFIG_CLUSTER2="/Users/mwojciechowski/.kube/hlf-fra-kubeconfig.yaml"
export ORDERER_CA_CLUSTER="/Users/mwojciechowski/.kube/hlf-ams-kubeconfig.yaml"

# Domains
export ORDERER_CA_DOMAIN="ord-ca.hlf-ord.tk"
export ORD1_DOMAIN="ord1.hlf-ord.tk"
export ORD2_DOMAIN="ord2.hlf-ord.tk"
export PEER0_ORG1_DOMAIN="peer0.hlf-ams.tk"
export PEER1_ORG1_DOMAIN="peer1.hlf-ams.tk"
export PEER0_ORG2_DOMAIN="peer0.hlf-fra.tk"
export PEER1_ORG2_DOMAIN="peer1.hlf-fra.tk"

# Chaincode
export CHAINCODE_PATH="../fabcar-js/"
export CHAINCODE_LANG="node"
export CHAINCODE_LABEL="fabcar"

# Network elements names
export ORD1_NODE=ord1-node
export ORD2_NODE=ord2-node
export PEER0_ORG1=peer0-ams
export PEER1_ORG1=peer1-ams
export PEER0_ORG2=peer0-fra
export PEER1_ORG2=peer1-fra
export ORG1_CA=org1-ca
export ORG2_CA=org2-ca
export ORDERER_CA=ord-ca

# Organizations
export ORG1=Org1MSP
export ORG2=Org2MSP
export ORGORD=OrdererMSP

# Istio/cluster config
export ISTIO_INGRESSGATEWAY=ingressgateway
export ISTIO_GW_PORT=443
export STORAGE_CLASS=do-block-storage
export CHANNEL_NAME=demo

# Other
# Color of logs
export COLOR="\033[0;35m"
export NC="\033[0m"
export MERGED_CONFIG=config.yaml

# Config paths, usernames and passwords
export ORG1_ENROLL_ID=enroll
export ORG1_ENROLL_SECRET=enrollpw
export ORG1_ADMIN_PATH=org1-admin.yaml
export ORG1_CONFIG=org1-config.yaml
export ORG1_ORDERER_CONFIG=org1-orderer-config.yaml
export ORG1_ADMIN_USERNAME=admin
export ORG1_ADMIN_PASSWORD=adminpw
export ORG1_ADMIN_TLS=org1-admin-tls.yaml
export ORG1_PEER0_USERNAME=peer0
export ORG1_PEER0_PASSWORD=peer0pw
export ORG1_PEER1_USERNAME=peer1
export ORG1_PEER1_PASSWORD=peer1pw

export ORG2_ENROLL_ID=enroll
export ORG2_ENROLL_SECRET=enrollpw
export ORG2_ADMIN_PATH=org2-admin.yaml
export ORG2_CONFIG=org2-config.yaml
export ORG2_ORDERER_CONFIG=org2-orderer-config.yaml
export ORG2_ADMIN_USERNAME=admin
export ORG2_ADMIN_PASSWORD=adminpw
export ORG2_DEFINITION=resources/org2/configtx.yaml
export ORG2_ADMIN_TLS=org2-admin-tls.yaml
export ORG2_PEER0_USERNAME=peer0
export ORG2_PEER0_PASSWORD=peer0pw
export ORG2_PEER1_USERNAME=peer1
export ORG2_PEER1_PASSWORD=peer1pw

export ORDERER_DEFINITION=resources/orderer/configtx.yaml
export ORDERER_ENROLL_ID=enroll
export ORDERER_ENROLL_SECRET=enrollpw
export ORDERER1_ADMIN_PATH=orderer1-admin.yaml
export ORDERER1_CONFIG=orderer1-config.yaml
export ORDERER1_DEPLOYMENT=resources/orderer/orderer1.yaml
export ORDERER1_ADMIN_USERNAME=admin1
export ORDERER1_ADMIN_PASSWORD=admin1pw
export ORDERER1_ADMIN_TLS=orderer1-admin-tls.yaml
export ORDERER1_ORDERER_USERNAME=orderer1
export ORDERER1_ORDERER_PASSWORD=orderer1pw

export ORDERER2_ADMIN_PATH=orderer2-admin.yaml
export ORDERER2_CONFIG=orderer2-config.yaml
export ORDERER2_DEPLOYMENT=resources/orderer/orderer2.yaml
export ORDERER2_ADMIN_USERNAME=admin2
export ORDERER2_ADMIN_PASSWORD=admin2pw
export ORDERER2_ADMIN_TLS=orderer2-admin-tls.yaml
export ORDERER2_ORDERER_USERNAME=orderer2
export ORDERER2_ORDERER_PASSWORD=orderer2pw

export POLICY_ADMIN="OR('${ORG1}.admin','${ORG2}.admin')"
export POLICY_MEMBER="OR('${ORG1}.member','${ORG2}.member')"
