#!/bin/bash

source ./env.sh

print() {
    echo -e ${COLOR}${1}${NC}
}

cleanup() {
    kubectl delete fabricorderingservices.hlf.kungfusoftware.es --all-namespaces --all
    kubectl delete fabricpeers.hlf.kungfusoftware.es --all-namespaces --all
    kubectl delete fabriccas.hlf.kungfusoftware.es --all-namespaces --all
    kubectl delete fabricorderernodes.hlf.kungfusoftware.es --all-namespaces --all
}

wait_for_istio() {
    print "Waiting for istio on cluster ${1##*/}..."
    while [[ $(kubectl get svc istio-ingressgateway -n istio-system --kubeconfig $1 -o json | jq -r '.status.loadBalancer.ingress[0].ip') == "null" ]]
    do
        print "Trying again in 5 seconds..."
        sleep 5
    done
    print "Istio on cluster ${1##*/} is ready"
}

wait_for_dns() {
    while [[ $(dig $1 +short) != "$2" ]]
    do
        print "Cluster1: $CLUSTER1_IP"
        print "Cluster2: $CLUSTER2_IP"
        print "Orderer cluster: $ORDERER_CA_IP"
        print "Domain $1 should be $2, currently $(dig $1 +short), trying again in 15 seconds..."
        sleep 15
    done
    print "$1 resolves to $2"
}

#
# Fabric functions
#
deploy_ca() {
    print "Deploying CA for $1"
    if [ -z "$5" ]
    then
        kubectl hlf ca create --storage-class $STORAGE_CLASS --capacity 1Gi --name $1 --enroll-id $2 --enroll-pw $3 --output > $4
    else 
        kubectl hlf ca create --storage-class $STORAGE_CLASS --capacity 1Gi --name $1 --enroll-id $2 --enroll-pw $3 --hosts $5 --output > $4
    fi
    kubectl apply -f $4
}

deploy_peer() {
    print "Deploying PEER $7"
    kubectl hlf ca register --name $1 --user $2 --secret $3 --type peer --enroll-id $4 --enroll-secret $5 --mspid $6
    kubectl hlf peer create --storage-class $STORAGE_CLASS --enroll-id $2 --mspid $6 \
            --enroll-pw $3 --capacity 2Gi --name $7 --ca-name ${1}.default \
            --hosts $8 --istio-ingressgateway $ISTIO_INGRESSGATEWAY --istio-port $ISTIO_GW_PORT \
            --output > $9
    kubectl apply -f $9
}

deploy_orderer() {
    print "Deploying ORDERER $7"
    KUBECONFIG=$ORDERER_CA_CLUSTER kubectl hlf ca register --name $ORDERER_CA --user $2 --secret $3 --type orderer --enroll-id $4 --enroll-secret $5 --mspid $6
    kubectl hlf ordnode create --storage-class $STORAGE_CLASS --enroll-id $4 --mspid $6 \
        --enroll-pw $5 --capacity 1Gi --name $7 --ca-name ${1}.default \
        --hosts $8 --istio-ingressgateway $ISTIO_INGRESSGATEWAY --istio-port $ISTIO_GW_PORT \
        --output > $9
    if [[ "$KUBECONFIG" != "$ORDERER_CA_CLUSTER" ]]
    then
        CA_CERT=$(yq '.spec.secret.enrollment.component.catls.cacert' $ORDERER1_DEPLOYMENT)
        yq -i "
            .spec.secret.enrollment.component.cahost |= \"$ORDERER_CA_DOMAIN\" | \
            .spec.secret.enrollment.component.caport |= 443 | \
            .spec.secret.enrollment.component.catls.cacert |= \"$CA_CERT\" | \
            .spec.secret.enrollment.tls.cahost |= \"$ORDERER_CA_DOMAIN\" | \
            .spec.secret.enrollment.tls.caport |= 443 | \
            .spec.secret.enrollment.tls.catls.cacert |= \"$CA_CERT\" | \
            .spec.secret.enrollment.tls.csr.hosts[6] |= \"$ORDERER_CA_DOMAIN\"
        " $9
    fi
    kubectl apply -f $9
}

create_connection_file() {
    print "Creating connection file $6"
    if [[ "$6" == "$ORGORD" ]]
    then
        KUBECONFIG=$ORDERER_CA_CLUSTER kubectl hlf ca register --name $1 --user $2 --secret $3 --type admin --enroll-id $4 --enroll-secret $5 --mspid $6
        KUBECONFIG=$ORDERER_CA_CLUSTER kubectl hlf ca enroll --name $1 --user $2 --secret $3 --mspid $6 --ca-name ca --output $7
    else
        kubectl hlf ca register --name $1 --user $2 --secret $3 --type admin --enroll-id $4 --enroll-secret $5 --mspid $6
        kubectl hlf ca enroll --name $1 --user $2 --secret $3 --mspid $6 --ca-name ca --output $7
    fi
    kubectl hlf inspect --output $8 --organizations $6
    kubectl hlf utils adduser --userPath $7 --config $8 --username $2 --mspid $6
}

join_channel_orderer() {
    print "Joining ORDERER $5 to the channel"
    KUBECONFIG=$ORDERER_CA_CLUSTER kubectl hlf ca enroll --name $1 --namespace default --user $2 --secret $3 --mspid $4 --ca-name tlsca --output $6
    kubectl hlf ordnode join --block ${CHANNEL_NAME}.block --name $5 --namespace default --identity $6
}

join_channel_peer() {
    print "Joining PEER $3 to the channel"
    while ! kubectl hlf channel join --name ${CHANNEL_NAME} --config $1 --user $2 --peer ${3}.default
    do
        print "Something went wrong, trying again in 15 seconds..."
        sleep 15
    done
}
add_anchor_peer() {
    print "Adding an anchor peer $3 to the channel"
    while ! kubectl hlf channel addanchorpeer --channel ${CHANNEL_NAME} --config $1 --user $2 --peer ${3}.default
    do
        print "Something went wrong, trying again in 15 seconds..."
        sleep 15
    done
}

add_org_to_channel() {
    print "Joining ORG $4 to the channel"
    kubectl hlf channel addorg --peer ${1}.default --name ${CHANNEL_NAME} --config $2 --user $3 --msp-id $4 --org-config $5
}

get_organization_definition() {
    print "Getting $1 definition"
    kubectl hlf org inspect -o $1 --output-path $2
    mv ./configtx.yaml $2
    yq -i " \
        .Organizations[0].Policies.Readers.Rule = \"$POLICY_MEMBER\" | \
        .Organizations[0].Policies.Writers.Rule = \"$POLICY_MEMBER\" | \
        .Organizations[0].Policies.Admins.Rule = \"$POLICY_ADMIN\" | \
        .Organizations[0].Policies.Endorsement.Rule = \"$POLICY_MEMBER\" \
    " $3
}

wait_for_fabric() {
    print "Waiting for fabric components..."
    kubectl wait --timeout 180s --for condition=Running fabriccas.hlf.kungfusoftware.es --all
    kubectl wait --timeout 180s --for condition=Running fabricpeers.hlf.kungfusoftware.es --all
    kubectl wait --timeout 180s --for condition=Running fabricorderernodes.hlf.kungfusoftware.es --all
    print "Fabric ready"
}

install_chaincode() {
    kubectl hlf chaincode install --path $CHAINCODE_PATH --config $2 --language $CHAINCODE_LANG --label $CHAINCODE_LABEL --user $3 --peer ${1}.default
}
approve_chaincode() {
    PACKAGE_ID=$(kubectl hlf chaincode queryinstalled --config $1 --user $2 --peer ${3}.default | awk 'NR == 2 {print $1}')
    kubectl hlf chaincode approveformyorg --config $1 --user $2 --peer ${3}.default \
        --package-id=$PACKAGE_ID \
        --version "1.0" --sequence $4 --name ${CHAINCODE_LABEL} \
        --policy $POLICY_MEMBER --channel ${CHANNEL_NAME}
}
commit_chaincode() {
    kubectl hlf chaincode commit --config $1 --mspid $3 --user $2 \
        --version "1.0" --sequence $4 --name ${CHAINCODE_LABEL} \
        --policy $POLICY_MEMBER --channel ${CHANNEL_NAME}
}
inspect_channel() {
    print "Inspecting channel"
    while ! kubectl hlf channel inspect --channel $CHANNEL_NAME --config $1 --user $2 --peer $3 > ${CHANNEL_NAME}_original.json
    do
        print "Something went wrong, trying again in 15 seconds..."
        sleep 15
    done
}