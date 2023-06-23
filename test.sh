#!/bin/bash

# Fabric network configuration
FABRIC_VERSION=2.2
NETWORK_NAME=myfabricnetwork
CHANNEL_NAME=mychannel
ORDERER_NAME=orderer.example.com
ORDERER_PORT=7050

# Peer organizations configuration
PEER_ORGS=("Org1" "Org2" "Org3" "Org4")
PEER_ORGS_DOMAINS=("org1.example.com" "org2.example.com" "org3.example.com" "org4.example.com")
PEER_ORGS_PORTS=(7051 8051 9051 10051)
PEER_ORGS_ANCHOR_PORTS=(7053 8053 9053 10053)

# Create network
function createNetwork() {
    echo "Creating Fabric network..."

    # Generate crypto material for orderer
    cryptogen generate --config=./crypto-config.yaml --output="crypto-config"

    # Generate genesis block
    configtxgen -profile FourOrgsOrdererGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block

    # Create channel transaction
    configtxgen -profile FourOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME

    # Create anchor peer update transactions for each org
    for ((i = 0; i < ${#PEER_ORGS[@]}; i++)); do
        org=${PEER_ORGS[$i]}
        orgDomain=${PEER_ORGS_DOMAINS[$i]}
        orgPort=${PEER_ORGS_ANCHOR_PORTS[$i]}

        configtxgen -profile FourOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/${org}MSPanchors.tx -channelID $CHANNEL_NAME -asOrg ${org}MSP
    done

    # Start orderer
    docker-compose -f docker-compose-orderer.yaml up -d

    # Create and join channels for each org
    for ((i = 0; i < ${#PEER_ORGS[@]}; i++)); do
        org=${PEER_ORGS[$i]}
        orgDomain=${PEER_ORGS_DOMAINS[$i]}
        orgPort=${PEER_ORGS_PORTS[$i]}
        orgAnchorPort=${PEER_ORGS_ANCHOR_PORTS[$i]}

        # Start peers and join channel
        docker-compose -f docker-compose-${org}.yaml up -d
        docker exec ${org}cli peer channel create -o $ORDERER_NAME:$ORDERER_PORT -c $CHANNEL_NAME -f /etc/hyperledger/configtx/channel.tx
        docker exec ${org}cli peer channel join -b $CHANNEL_NAME.block
        docker exec ${org}cli peer channel update -o $ORDERER_NAME:$ORDERER_PORT -c $CHANNEL_NAME -f /etc/hyperledger/configtx/${org}MSPanchors.tx
    done

    echo "Fabric network created successfully!"
}

# Start script
createNetwork
