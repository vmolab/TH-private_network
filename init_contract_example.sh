#!/bin/bash

# run this script when you first git clone the repository

cd src

# python3 send_eth.py
go run send_eth.go

cd ..


cd acs-eth-contract

go mod init acs-eth
go mod tidy

./abigen.sh


export RPC_URL=http://127.0.0.1:8801
export PRIVATE_KEY="0x22ef4acf63d23cf850986470d5f777cc60b57cdc79b6b2e4d141601448559d26"
export CHAIN_ID="81231"
export ACS_REGISTRY_ADDR="0x5A6E1EFA4F0E043a687A625d1e29E75C7c746017"

RPC_URL=$RPC_URL \
PRIVATE_KEY=$PRIVATE_KEY \
CHAIN_ID=$CHAIN_ID \
ACS_REGISTRY_ADDR=$ACS_REGISTRY_ADDR \
./deploy-contract.sh

RPC_URL=$RPC_URL \
PRIVATE_KEY=$PRIVATE_KEY \
CHAIN_ID=$CHAIN_ID \
ACS_REGISTRY_ADDR=$ACS_REGISTRY_ADDR \
./check-contract.sh