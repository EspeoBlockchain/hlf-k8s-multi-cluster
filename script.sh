#!/bin/bash

source ./env.sh
source ./functions.sh

#
#
# Previous environment cleanup
#
#

print "Cleanup"
rm -rf *.pb *.public *.yaml *.block *.json keystore msp org2-config peerOrganizations resources 
KUBECONFIG=$CONFIG_CLUSTER1 cleanup
KUBECONFIG=$CONFIG_CLUSTER2 cleanup



#
#
# HLF Operator and istio deployments
#
#

KUBECONFIG=$CONFIG_CLUSTER1 helm install hlf-operator --version=1.6.0 kfs/hlf-operator &
KUBECONFIG=$CONFIG_CLUSTER1 istioctl install -y &
KUBECONFIG=$CONFIG_CLUSTER2 helm install hlf-operator --version=1.6.0 kfs/hlf-operator &
KUBECONFIG=$CONFIG_CLUSTER2 istioctl install -y &
print "Istio and HLF Operator installed"

# Wait for Istio load balancer to get public IP
wait
wait_for_istio $CONFIG_CLUSTER1 
wait_for_istio $CONFIG_CLUSTER2
print "Istio is ready"



#
#
# DNS checks
#
#

export CLUSTER1_IP=$(kubectl get svc istio-ingressgateway -n istio-system --kubeconfig $CONFIG_CLUSTER1 -o json | jq -r '.status.loadBalancer.ingress[0].ip')
export CLUSTER2_IP=$(kubectl get svc istio-ingressgateway -n istio-system --kubeconfig $CONFIG_CLUSTER2 -o json | jq -r '.status.loadBalancer.ingress[0].ip')
export ORDERER_CA_IP=$(kubectl get svc istio-ingressgateway -n istio-system --kubeconfig $ORDERER_CA_CLUSTER -o json | jq -r '.status.loadBalancer.ingress[0].ip')

print "Waiting DNS updates..."
wait_for_dns $PEER0_ORG1_DOMAIN $CLUSTER1_IP 
wait_for_dns $PEER1_ORG1_DOMAIN $CLUSTER1_IP 
wait_for_dns $ORD1_DOMAIN $CLUSTER1_IP 

wait_for_dns $PEER0_ORG2_DOMAIN $CLUSTER2_IP 
wait_for_dns $PEER1_ORG2_DOMAIN $CLUSTER2_IP 
wait_for_dns $ORD2_DOMAIN $CLUSTER2_IP

wait_for_dns $ORDERER_CA_DOMAIN $ORDERER_CA_IP

print "DNS is ready"


mkdir -p resources/{org1,org2,orderer}



#
#
# Fabric deployments
#
#

# Deploy CA for ORG1
export KUBECONFIG=$CONFIG_CLUSTER1
deploy_ca $ORG1_CA $ORG1_ENROLL_ID $ORG1_ENROLL_SECRET resources/org1/ca.yaml
deploy_ca $ORDERER_CA $ORDERER_ENROLL_ID $ORDERER_ENROLL_SECRET resources/orderer/ca.yaml $ORDERER_CA_DOMAIN
# Deploy CA for ORG2
export KUBECONFIG=$CONFIG_CLUSTER2
deploy_ca $ORG2_CA $ORG2_ENROLL_ID $ORG2_ENROLL_SECRET resources/org2/ca.yaml
sleep 5
KUBECONFIG=$CONFIG_CLUSTER1 wait_for_fabric
KUBECONFIG=$CONFIG_CLUSTER2 wait_for_fabric

# Deploys for ORG1
export KUBECONFIG=$CONFIG_CLUSTER1
deploy_peer $ORG1_CA peer0 peer0pw $ORG1_ENROLL_ID $ORG1_ENROLL_SECRET $ORG1 $PEER0_ORG1 $PEER0_ORG1_DOMAIN resources/org1/peer0.yaml
deploy_peer $ORG1_CA peer1 peer1pw $ORG1_ENROLL_ID $ORG1_ENROLL_SECRET $ORG1 $PEER1_ORG1 $PEER1_ORG1_DOMAIN resources/org1/peer1.yaml
deploy_orderer $ORDERER_CA orderer1 orderer1pw $ORDERER_ENROLL_ID $ORDERER_ENROLL_SECRET $ORGORD $ORD1_NODE $ORD1_DOMAIN $ORDERER1_DEPLOYMENT
# Deploys for ORG2
export KUBECONFIG=$CONFIG_CLUSTER2
deploy_peer $ORG2_CA peer0 peer0pw $ORG2_ENROLL_ID $ORG2_ENROLL_SECRET $ORG2 $PEER0_ORG2 $PEER0_ORG2_DOMAIN resources/org2/peer0.yaml
deploy_peer $ORG2_CA peer1 peer1pw $ORG2_ENROLL_ID $ORG2_ENROLL_SECRET $ORG2 $PEER1_ORG2 $PEER1_ORG2_DOMAIN resources/org2/peer1.yaml
deploy_orderer $ORG2_CA orderer2 orderer2pw $ORDERER_ENROLL_ID $ORDERER_ENROLL_SECRET $ORGORD $ORD2_NODE $ORD2_DOMAIN $ORDERER2_DEPLOYMENT
KUBECONFIG=$CONFIG_CLUSTER1 wait_for_fabric
KUBECONFIG=$CONFIG_CLUSTER2 wait_for_fabric



#
#
# Getting connection files
#
#
export KUBECONFIG=$CONFIG_CLUSTER1

# Connection file for ORG1
create_connection_file $ORG1_CA $ORG1_ADMIN_USERNAME $ORG1_ADMIN_PASSWORD $ORG1_ENROLL_ID $ORG1_ENROLL_SECRET $ORG1 $ORG1_ADMIN_PATH $ORG1_CONFIG
create_connection_file $ORDERER_CA $ORDERER1_ADMIN_USERNAME $ORDERER1_ADMIN_PASSWORD $ORDERER_ENROLL_ID $ORDERER_ENROLL_SECRET $ORGORD $ORDERER1_ADMIN_PATH $ORDERER1_CONFIG

# Connection file for ORG2
export KUBECONFIG=$CONFIG_CLUSTER2
create_connection_file $ORG2_CA $ORG2_ADMIN_USERNAME $ORG2_ADMIN_PASSWORD $ORG2_ENROLL_ID $ORG2_ENROLL_SECRET $ORG2 $ORG2_ADMIN_PATH $ORG2_CONFIG
create_connection_file $ORDERER_CA $ORDERER2_ADMIN_USERNAME $ORDERER2_ADMIN_PASSWORD $ORDERER_ENROLL_ID $ORDERER_ENROLL_SECRET $ORGORD $ORDERER2_ADMIN_PATH $ORDERER2_CONFIG

# Merge connection files
yq eval-all '. as $item ireduce ({}; . *+ $item)' $ORDERER1_CONFIG $ORG1_CONFIG > $ORG1_ORDERER_CONFIG
yq eval-all '. as $item ireduce ({}; . *+ $item)' $ORG2_CONFIG $ORDERER2_CONFIG > $ORG2_ORDERER_CONFIG
yq eval-all '. as $item ireduce ({}; . *+ $item)' $ORDERER1_CONFIG $ORDERER2_CONFIG $ORG2_CONFIG $ORG1_CONFIG > $MERGED_CONFIG
yq eval -i  ".channels._default.orderers=(.channels._default.orderers | unique)" $MERGED_CONFIG 

KUBECONFIG=$CONFIG_CLUSTER1 install_chaincode $PEER0_ORG1 $ORG1_CONFIG $ORG1_ADMIN_USERNAME &
KUBECONFIG=$CONFIG_CLUSTER1 install_chaincode $PEER1_ORG1 $ORG1_CONFIG $ORG1_ADMIN_USERNAME &
KUBECONFIG=$CONFIG_CLUSTER2 install_chaincode $PEER0_ORG2 $ORG2_CONFIG $ORG2_ADMIN_USERNAME &
KUBECONFIG=$CONFIG_CLUSTER2 install_chaincode $PEER1_ORG2 $ORG2_CONFIG $ORG2_ADMIN_USERNAME &



#
#
# ORG1
#
#
export KUBECONFIG=$CONFIG_CLUSTER1
# Create channel ORG1
print "Creating channel"
kubectl hlf channel generate --output ${CHANNEL_NAME}.block --name ${CHANNEL_NAME} --organizations $ORG1 --ordererOrganizations $ORGORD

# Join channel ORDERER ORG1
join_channel_orderer $ORDERER_CA $ORDERER1_ADMIN_USERNAME $ORDERER1_ADMIN_PASSWORD $ORGORD $ORD1_NODE $ORDERER1_ADMIN_TLS
join_channel_peer $ORG1_CONFIG $ORG1_ADMIN_USERNAME $PEER0_ORG1
join_channel_peer $ORG1_CONFIG $ORG1_ADMIN_USERNAME $PEER1_ORG1
add_anchor_peer $ORG1_CONFIG $ORG1_ADMIN_USERNAME $PEER0_ORG1



#
#
# ORG2
#
#
export KUBECONFIG=$CONFIG_CLUSTER2

# Add ORG2 to channel
get_organization_definition $ORG2 ./resources/org2 $ORG2_DEFINITION
KUBECONFIG=$CONFIG_CLUSTER1 add_org_to_channel $PEER0_ORG1 $ORG1_CONFIG $ORG1_ADMIN_USERNAME $ORG2 $ORG2_DEFINITION
join_channel_orderer $ORDERER_CA $ORDERER2_ADMIN_USERNAME $ORDERER2_ADMIN_PASSWORD $ORGORD $ORD2_NODE $ORDERER2_ADMIN_TLS

# Modify channel to include ORD2 as consenter
sleep 5
export KUBECONFIG=$CONFIG_CLUSTER1
inspect_channel $MERGED_CONFIG $ORG1_ADMIN_USERNAME ${PEER0_ORG1}.default
$CONFIGTXLATOR proto_encode --input ${CHANNEL_NAME}_original.json --type common.Config --output config.pb
ORD2_POD_NAME=$(KUBECONFIG=$CONFIG_CLUSTER2 kubectl get pods -o name | grep ${ORD2_NODE} | sed "s/^.\{4\}//")
ORD2_CERT=$(KUBECONFIG=$CONFIG_CLUSTER2 kubectl exec -it ${ORD2_POD_NAME} -- cat /var/hyperledger/tls/server/pair/tls.crt | sed -e "s/\r//g" | base64)
jq " \
    .channel_group.groups.Orderer.groups.OrdererMSP.values.Endpoints.value.addresses[1] |= . + \"${ORD2_DOMAIN}:${ISTIO_GW_PORT}\" | \
    .channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters[1] |= {\"host\": \"${ORD2_DOMAIN}\", \"port\": ${ISTIO_GW_PORT}, \"client_tls_cert\": \"${ORD2_CERT}\", \"server_tls_cert\": \"${ORD2_CERT}\", } \
" ${CHANNEL_NAME}_original.json > ${CHANNEL_NAME}_update.json
$CONFIGTXLATOR proto_encode --input ${CHANNEL_NAME}_update.json --type common.Config --output modified_config.pb
$CONFIGTXLATOR compute_update --channel_id ${CHANNEL_NAME} --original config.pb --updated modified_config.pb --output config_update.pb
$CONFIGTXLATOR proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
$CONFIGTXLATOR proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb
kubectl hlf channel signupdate --channel ${CHANNEL_NAME} -f config_update_in_envelope.pb --user $ORDERER1_ADMIN_USERNAME --config $MERGED_CONFIG --mspid $ORGORD --output ord-demo-update-sign.pb
kubectl hlf channel update --channel ${CHANNEL_NAME} -f config_update_in_envelope.pb --config $ORG1_CONFIG --user $ORG1_ADMIN_USERNAME --mspid $ORG1 --signatures ord-demo-update-sign.pb

# Join to channel
export KUBECONFIG=$CONFIG_CLUSTER2
join_channel_peer $ORG2_CONFIG $ORG2_ADMIN_USERNAME $PEER0_ORG2
join_channel_peer $ORG2_CONFIG $ORG2_ADMIN_USERNAME $PEER1_ORG2
add_anchor_peer $ORG2_CONFIG $ORG2_ADMIN_USERNAME $PEER0_ORG2

#
#
# CHAINCODE
#
#
print "Waiting for chaincode to finish installing"
wait # for chaincode to be installed
SEQUENCE=1
KUBECONFIG=$CONFIG_CLUSTER1 approve_chaincode $MERGED_CONFIG $ORG1_ADMIN_USERNAME $PEER0_ORG1 $SEQUENCE
KUBECONFIG=$CONFIG_CLUSTER2 approve_chaincode $MERGED_CONFIG $ORG2_ADMIN_USERNAME $PEER0_ORG2 $SEQUENCE

KUBECONFIG=$CONFIG_CLUSTER1 commit_chaincode $ORG1_CONFIG $ORG1_ADMIN_USERNAME $ORG1 $SEQUENCE

KUBECONFIG=$CONFIG_CLUSTER1 kubectl hlf chaincode invoke --config $ORG1_CONFIG --user $ORG1_ADMIN_USERNAME --peer ${PEER0_ORG1}.default --chaincode $CHAINCODE_LABEL --channel $CHANNEL_NAME --fcn initLedger -a '[]'

KUBECONFIG=$CONFIG_CLUSTER1 kubectl hlf chaincode invoke --config $ORG1_CONFIG --user $ORG1_ADMIN_USERNAME --peer ${PEER0_ORG1}.default --chaincode $CHAINCODE_LABEL --channel $CHANNEL_NAME --fcn addProject --args 'Peer0Org1' --args 'recClientKey' --args 'refClientKey' --args 'netInvoice' --args 'creationDate' --args 'modificationDate' --args 'parentCompany'
KUBECONFIG=$CONFIG_CLUSTER1 kubectl hlf chaincode invoke --config $ORG1_CONFIG --user $ORG1_ADMIN_USERNAME --peer ${PEER1_ORG1}.default --chaincode $CHAINCODE_LABEL --channel $CHANNEL_NAME --fcn addProject --args 'Peer1Org1' --args 'recClientKey' --args 'refClientKey' --args 'netInvoice' --args 'creationDate' --args 'modificationDate' --args 'parentCompany'
KUBECONFIG=$CONFIG_CLUSTER2 kubectl hlf chaincode invoke --config $ORG2_CONFIG --user $ORG2_ADMIN_USERNAME --peer ${PEER0_ORG2}.default --chaincode $CHAINCODE_LABEL --channel $CHANNEL_NAME --fcn addProject --args 'Peer0Org2' --args 'recClientKey' --args 'refClientKey' --args 'netInvoice' --args 'creationDate' --args 'modificationDate' --args 'parentCompany'
KUBECONFIG=$CONFIG_CLUSTER2 kubectl hlf chaincode invoke --config $ORG2_CONFIG --user $ORG2_ADMIN_USERNAME --peer ${PEER1_ORG2}.default --chaincode $CHAINCODE_LABEL --channel $CHANNEL_NAME --fcn addProject --args 'Test123' --args 'recClientKey' --args 'refClientKey' --args 'netInvoice' --args 'creationDate' --args 'modificationDate' --args 'parentCompany'

KUBECONFIG=$CONFIG_CLUSTER1 kubectl hlf chaincode query --config $ORG1_CONFIG --user $ORG1_ADMIN_USERNAME --peer ${PEER0_ORG1}.default --chaincode $CHAINCODE_LABEL --channel $CHANNEL_NAME --fcn readProject --args 'Test123' | jq
KUBECONFIG=$CONFIG_CLUSTER1 kubectl hlf chaincode query --config $ORG1_CONFIG --user $ORG1_ADMIN_USERNAME --peer ${PEER1_ORG1}.default --chaincode $CHAINCODE_LABEL --channel $CHANNEL_NAME --fcn readProject --args 'Peer0Org2' | jq
KUBECONFIG=$CONFIG_CLUSTER2 kubectl hlf chaincode query --config $ORG2_CONFIG --user $ORG2_ADMIN_USERNAME --peer ${PEER0_ORG2}.default --chaincode $CHAINCODE_LABEL --channel $CHANNEL_NAME --fcn readProject --args 'Peer0Org2' | jq
KUBECONFIG=$CONFIG_CLUSTER2 kubectl hlf chaincode query --config $ORG2_CONFIG --user $ORG2_ADMIN_USERNAME --peer ${PEER1_ORG2}.default --chaincode $CHAINCODE_LABEL --channel $CHANNEL_NAME --fcn readProject --args 'Peer0Org2' | jq
