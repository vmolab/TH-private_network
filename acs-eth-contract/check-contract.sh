#!/bin/bash
#export PRIVATE_KEY=$(openssl rand -hex 32)
#export GREETER_ADDR=$(openssl rand -hex 16)

export RPC_URL=http://127.0.0.1:8545
#export PUBLIC_KEY=0xB92d326096901Ec362e15D9567e2faE5Cf027766
export PRIVATE_KEY=0x22ef4acf63d23cf850986470d5f777cc60b57cdc79b6b2e4d141601448559d26
export ACS_REGISTRY_ADDR=0x2CCAFA83fFb506beab62e20798F9ba47647b5077
export CHAIN_ID=1337  # 예: Hardhat/Ganache

go run ./utils/check-contract/checker.go
