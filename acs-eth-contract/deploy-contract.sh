#!/bin/bash
export RPC_URL=http://127.0.0.1:8545
export PRIVATE_KEY=0x22ef4acf63d23cf850986470d5f777cc60b57cdc79b6b2e4d141601448559d26
#export ACS_REGISTRY_ADDR=0x2CCAFA83fFb506beab62e20798F9ba47647b5077
export CHAIN_ID=1337  # 예: Hardhat/Ganache

go run utils/deploy-contract/deployer.go
