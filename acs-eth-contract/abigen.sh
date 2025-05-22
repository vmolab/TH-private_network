#!/bin/bash
solc --evm-version paris --abi --bin --optimize --via-ir --overwrite -o contracts contracts/AcsRegistry.sol
#solc --abi -o contracts/ contracts/AcsContract.sol
#solc --bin contracts/AcsContract.sol -o contracts/

abigen --abi contracts/AcsRegistry.abi \
       --bin contracts/AcsRegistry.bin \
       --pkg contracts \
       --out contracts/AcsRegistry.go
