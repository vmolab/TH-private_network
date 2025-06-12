#!/bin/bash
# init.sh

# random chain id
CHAIN_ID=81231

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


# copy the password file and genesis.json from the current directory to the data directory
cp -r ../keystore .
cp ../genesis.json .



# # clone go-ethereum repo
# if [ -d go-ethereum ]; then
#     echo "go-ethereum directory already exists, skipping clone"
# else
#     git clone https://github.com/3e91b5/impt_go-ethereum.git go-ethereum
# fi
cp -r /home/jhkim/go/src/github.com/3e91b5/impt_go-ethereum go-ethereum
cd go-ethereum

# git reset --hard e5eb32acee19cc9fca6a03b10283b7484246b15a

# using Dockerfile in the go-ethereum repo
if [ $(docker images -q geth:impt 2> /dev/null) ]; then
    echo "Image already exists, skipping build"
else
    echo "Building geth image"
    docker build . -t geth:impt
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


    docker run --rm --name node$i \
        -v $(pwd)/data/node$i:/root/.ethereum \
        -v $(pwd)/genesis.json:/root/genesis.json \
        -v $(pwd)/keystore:/root/keystore \
        geth:impt \
        --datadir /root/.ethereum \
        init "/root/genesis.json" > /dev/null 2>&1


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
        --verbosity 4 \
        --syncmode full \
        --networkid $CHAIN_ID \
        --mine \
        --miner.threads 1 \
        --ws \
        --wsaddr 0.0.0.0 \
        --wsorigins "*" \
        --keystore /root/keystore --gcmode archive \
        --rpc \
        --rpccorsdomain "procyon.snu.ac.kr" \
        --rpcvhosts "procyon.snu.ac.kr,localhost" \
        --rpcport 880$i \
        --rpcaddr 0.0.0.0 \
        --nodiscover\
        --rpcapi="admin,db,eth,debug,miner,net,shh,txpool,personal,web3,trace" \
        --allow-insecure-unlock \
        --fakeimpt \
        > $(pwd)/data/node$i/geth.log 2>&1 # 로그를 파일로 리디렉션
    echo "Node $i started, logs at $(pwd)/data/node$i/geth.log"
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
