from web3 import Web3
import sys
import random
import time
import os,binascii
from datetime import datetime
from multiprocessing import Pool

# Settings
FULL_PORT = "8081"
PASSWORD = "1234"

# multiprocessing to send transactions
THREAD_COUNT = 1

# tx arguments option
INCREMENTAL_RECEIVER_ADDRESS = False # set tx receiver: incremental vs random
MAX_ADDRESS = 100000000              # set max address to set the receiver address upper bound (0 means there is no bound)
INCREMENTAL_SEND_AMOUNT = True       # set send amount: incremental vs same (1 wei)

# providers
fullnode = Web3(Web3.HTTPProvider("http://localhost:" + FULL_PORT))

# functions
def main(accountNum, txPerBlock, miningThreadNum):
    
    ACCOUNT_NUM = accountNum
    TX_PER_BLOCK = txPerBlock
    MINING_THREAD_NUM = miningThreadNum # Geth's mining option

    if ACCOUNT_NUM < TX_PER_BLOCK:
        print("too less accounts. at least", TX_PER_BLOCK, "accounts are needed")
        return

    print("Insert ", ACCOUNT_NUM, " accounts")
    print("tx per block:", TX_PER_BLOCK)
    print("geth mining thread:", MINING_THREAD_NUM, "\n")

    # unlock coinbase
    fullnode.geth.personal.unlockAccount(fullnode.eth.coinbase, PASSWORD, 0)

    # get current block
    currentBlock = fullnode.eth.blockNumber

    # main loop for send txs
    print("start sending transactions")
    startTime = datetime.now()
    offset = 1
    cnt = 0
    txNums = [int(TX_PER_BLOCK/THREAD_COUNT)]*THREAD_COUNT
    txNums[0] += TX_PER_BLOCK%THREAD_COUNT
    for i in range(int(ACCOUNT_NUM / TX_PER_BLOCK)):
        # 블록 생성 시작 시간 기록
        block_start_time = datetime.now()
        
        # set arguments for multithreading function
        arguments = []
        for j in range(THREAD_COUNT):
            arguments.append((txNums[j], offset))
            offset += txNums[j]
        
        # send transactions
        sendPool.starmap(sendTransactions, arguments)
        cnt = cnt + TX_PER_BLOCK
        if cnt % 10000 == 0:
            elapsed = datetime.now() - startTime
            print("inserted ", (i+1)*TX_PER_BLOCK, "accounts / elapsed time:", elapsed)

        # mining
        fullnode.geth.miner.start(MINING_THREAD_NUM)  # start mining with multiple threads
        while (fullnode.eth.blockNumber == currentBlock):
            pass # just wait for mining
        fullnode.geth.miner.stop()  # stop mining
        currentBlock = fullnode.eth.blockNumber
        
        # 블록 생성에 걸린 시간 계산 및 조정
        elapsed_time = (datetime.now() - block_start_time).total_seconds()
        if elapsed_time < 10:
            print(f"Waiting {10 - elapsed_time:.2f} seconds to make block time exactly 10 seconds")
            time.sleep(10 - elapsed_time)
        else:
            print(f"Block creation took {elapsed_time:.2f} seconds (more than 10 seconds)")


def sendTransaction(to):
    while True:
        try:
            fullnode.eth.sendTransaction(
                {'to': to, 'from': fullnode.eth.coinbase, 'value': '1', 'gas': '21000', 'data': ""})
            break
        except:
            continue


def sendTransactions(num, offset):
    for i in range(int(num)):
        # set receiver
        if INCREMENTAL_RECEIVER_ADDRESS:
            to = intToAddr(int(offset+i))
        else:
            # if the upper bound is set, select receiver within the bound
            if MAX_ADDRESS != 0:
                to = intToAddr(random.randint(1, MAX_ADDRESS))
            # just any random address
            else:
                to = makeRandHex()
        
# to = "0xe4f853b9d237b220f0ECcdf55d224c54a30032Df"
        
        # set send amount
        if INCREMENTAL_SEND_AMOUNT:
            amount = int(offset+i)
        else:
            amount = int(1)

# print("to: ", to, "/ from: ", fullnode.eth.coinbase, "/ amount:", amount)

        while True:
            try:
                fullnode.eth.sendTransaction(
                    {'to': to, 'from': fullnode.eth.coinbase, 'value': hex(amount), 'gas': '21000', 'data': ""})
                break
            except:
                time.sleep(1)
                continue


def makeRandHex():
    randHex = binascii.b2a_hex(os.urandom(20))
    return Web3.toChecksumAddress("0x" + randHex.decode('utf-8'))


def intToAddr(num):
    intToHex = f'{num:0>40x}'
    return Web3.toChecksumAddress("0x" + intToHex)


if __name__ == "__main__":
    startTime = datetime.now()
    sendPool = Pool(THREAD_COUNT)

    # 스레드 수를 8로 고정
    threadNum = 8
    
    # TH 설정
    totalTxNum = 200
    txPerBlock = 200

    # print(f"시작: 고정 스레드 수 {threadNum}, 블록당 {txPerBlock} 트랜잭션, 블록 생성 시간 10초")
    
    # 무한 루프로 실행
    try:
        while True:

            main(totalTxNum, txPerBlock, threadNum)
            # main(1, 1, threadNum) # for test
            elapsed = datetime.now() - startTime
            print(f"블록 생성 완료. 총 경과 시간: {elapsed}")
            print("")
    except KeyboardInterrupt:
        print("\n사용자에 의해 중단되었습니다.")
        
    elapsed = datetime.now() - startTime
    print("총 경과 시간:", elapsed)
    print("종료됨")
    