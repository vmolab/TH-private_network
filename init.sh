#!/bin/bash
# init.sh

# random chain id
CHAIN_ID=81231

# random account which initially holds 100,000,000,000 ether
# MASTER_ADDRESS=0xD04136b9F4984a0e8Ffd682d22f1a29A03F19c41
MASTER_ADDRESS=0xc4422d1C18E9Ead8A9bB98Eb0d8bB9dbdf2811D7
MASTER_PRIVATE_KEY=0xfb559405a8d302f7c9e12877fb73277cb0616548935082e91436127e30d73035
mkdir -p eth_private_network
cd eth_private_network

mkdir -p data

for i in $(seq 1 $1)
do
    # data directory for each node
    mkdir -p data/node$i

    # FIXME: makeshift for permission issues
    mkdir -p data/node$i/keystore
    mkdir -p data/node$i/geth
done

# londonBlock for EIP-1559
cat > genesis.json <<EOF
{
  "config": {
    "chainId": $CHAIN_ID,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "muirGlacierBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "ethash": {}
  },
  "difficulty": "1",
  "gasLimit": "21000000",
  "alloc": {
    "$MASTER_ADDRESS": {
      "balance": "1000000000000000000000000000"
    }
  }
}
EOF

# password to create the account and unlock it
# cat > password.txt <<EOF
# 1234567890
# 1234567890
# EOF
cat > password.txt <<EOF
1234
1234
EOF



# clone go-ethereum repo
if [ -d go-ethereum ]; then
    echo "go-ethereum directory already exists, skipping clone"
else
    git clone https://github.com/3e91b5/impt_go-ethereum.git go-ethereum
fi

cd go-ethereum

# git reset --hard e5eb32acee19cc9fca6a03b10283b7484246b15a

# using Dockerfile in the go-ethereum repo
if [ $(docker images -q geth:impt 2> /dev/null) ]; then
    echo "Image already exists, skipping build"
else
    echo "Building geth image"
    # 빌드 캐시·멀티플랫폼을 쓸 수 있는 buildx 권장
    GOPROXY_LIST="https://goproxy.io,https://goproxy.cn,direct"
    GOSUMDB_SERVER="sum.golang.google.cn"

    docker buildx build --network=host \
    --build-arg GOPROXY="$GOPROXY_LIST" \
    --build-arg GOSUMDB="$GOSUMDB_SERVER" \
    -t geth:1.10.26 .
fi

cd ..

# docker network for the private network
if docker network inspect eth_private_network > /dev/null 2>&1; then
    echo "Docker network already exists, skipping creation"
else
    docker network create --gateway 10.10.10.1 --subnet 10.10.10.0/24 -d bridge eth_private_network
fi

for i in $(seq 1 $1)
do
    # account creation - 마스터 계정을 각 노드에 임포트
    echo $MASTER_PRIVATE_KEY > data/node$i/master_key.txt

    # 마스터 계정을 keystore로 임포트
    docker run --rm --name node$i \
        -v $(pwd)/data/node$i:/root/.ethereum \
        -v $(pwd)/genesis.json:/root/genesis.json \
        -v $(pwd)/password.txt:/root/password.txt \
        geth:1.10.26 \
        account import \
        --password /root/password.txt \
        --datadir /root/.ethereum \
        /root/.ethereum/master_key.txt

    # 보안을 위해 개인키 파일 삭제
    rm data/node$i/master_key.txt



    # # account creation
    # docker run --rm --name node$i \
    #     -v $(pwd)/data/node$i:/root/.ethereum \
    #     -v $(pwd)/genesis.json:/root/genesis.json \
    #     -v $(pwd)/password.txt:/root/password.txt \
    #     geth:1.10.26 \
    #     account new \
    #     --password /root/password.txt \
    #     --datadir /root/.ethereum > /dev/null 2>&1

    # init the node with the genesis block
    docker run --rm --name node$i \
        -v $(pwd)/data/node$i:/root/.ethereum \
        -v $(pwd)/genesis.json:/root/genesis.json \
        -v $(pwd)/password.txt:/root/password.txt \
        geth:1.10.26 \
        init --datadir /root/.ethereum \
        "/root/genesis.json" > /dev/null 2>&1

    # fetch the enode address of each node
    docker run --rm --name node$i \
        -v $(pwd)/data/node$i:/root/.ethereum \
        -v $(pwd)/genesis.json:/root/genesis.json \
        -v $(pwd)/keystore:/root/keystore \
        geth:impt \
        --verbosity 0 \
        console --exec admin.nodeInfo.enode | awk -F "@" '{printf $1}' > data/node$i/enode.txt
        echo -n "@10.10.10.1${i}:30303\"" >> data/node$i/enode.txt
done




for i in $(seq 1 $1)
do
    # create the static-nodes.json file for each node
    # deprecated method!
    cat > data/node$i/static-nodes.json <<EOF
[
EOF
    
    COUNT=0
    for j in $(seq 1 $1)
    do
        # skip the current node
        if [[ $i -ne $j ]]; then
            COUNT=$((COUNT + 1))
            ENODE=$(cat data/node$j/enode.txt)

            # add a comma if it's not the last node
            if [[ $COUNT -ne $(( $1 - 1 )) ]]; then
                ENODE+=","
            fi

            echo "    $ENODE" >> data/node$i/static-nodes.json
        fi
    done

    echo -n "]" >> data/node$i/static-nodes.json

    # starting the node$i
    #
    # ports:
    #   P2P:                3030$i
    #   Auth:               551$i
    #   JSON-RPC Server:    545$i
    #   WebSocket Server:   546$i
    #

    docker run -d  --name node$i \
        --network eth_private_network \
        --ip 10.10.10.1$i \
        -v $(pwd)/data/node$i:/root/.ethereum \
        -v $(pwd)/genesis.json:/root/genesis.json \
        -v $(pwd)/keystore:/root/keystore \
        -p 3030$i:30303 \
        -p 551$i:8551 \
        -p 880$i:880$i \
        -p 546$i:8546 \
        geth:impt \
        --datadir /root/.ethereum \
        --syncmode full \
        --networkid $CHAIN_ID \
        --mine \
        --miner.threads 1 \
        --miner.etherbase $MASTER_ADDRESS \
        --password /root/password.txt \
        --http \
        --http.addr 0.0.0.0 \
        --http.vhosts "*" \
        --http.api "eth,net,web3,personal,miner,admin" \
        --ws \
        --ws.addr 0.0.0.0 \
        --ws.origins "*" \
        --allow-insecure-unlock \
        > /dev/null 2>&1
    echo "Node $i started"
done

cd ..


# Build the miner script image if it doesn't exist
if ! docker image inspect miner-script:latest &> /dev/null; then
    echo "Building miner-script image..."
    docker build -t miner-script -f src/Dockerfile.miner src/
else
    echo "miner-script image already exists."
fi

NODE1_IP="10.10.10.11"
NODE1_RPC_PORT="8801"
# Run the miner script in a new Docker container
echo "Starting miner script in a Docker container..."
docker run -d --name miner_script_container \
    --network eth_private_network \
    miner-script \
    --fullnode "http://${NODE1_IP}:${NODE1_RPC_PORT}"

echo "Miner script container started."
