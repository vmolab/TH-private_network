#!/usr/bin/env python3
"""
fixed_interval_miner.py

Mine a new block every 10 seconds (approx) regardless of pending transactions.
The script continuously starts the miner, waits until the next block is sealed,
then sleeps just long enough so that each block cycle takes ~10 seconds in total.

Environment variables that can be set before running:
  FULL_PORT         JSON-RPC port of the node (default 8801)
  PASSWORD          Account unlock password (default 1234)
  THREADS           Number of mining threads to use (default 1)

Usage:
  python fixed_interval_miner.py            # with defaults
  FULL_PORT=8545 THREADS=4 python fixed_interval_miner.py
"""

from web3 import Web3
import time
from datetime import datetime
import os
from multiprocessing import Pool

# Configuration --------------------------------------------------------------
FULL_PORT = "8801"
PASSWORD = "1234"
THREAD_COUNT = 1
BLOCK_INTERVAL = 10  # seconds

# Web3 provider --------------------------------------------------------------
fullnode = Web3(Web3.HTTPProvider("http://localhost:" + FULL_PORT))

# Helper functions -----------------------------------------------------------

def ensure_coinbase_unlocked() -> str:
    """Unlock the coinbase account indefinitely (password='PASSWORD')."""
    if not fullnode.geth.personal.listAccounts():
        raise RuntimeError("No accounts present in node; cannot unlock coinbase.")

    coinbase = fullnode.eth.coinbase
    if not fullnode.geth.personal.unlockAccount(coinbase, PASSWORD, 0):
        raise RuntimeError("Failed to unlock coinbase account. Check PASSWORD.")
    return coinbase


def mine_forever(interval_sec: int, threads: int) -> None:
    """Mine one block per *interval_sec* seconds forever."""
    current_block = fullnode.eth.blockNumber

    while True:
        cycle_start = time.time()

        # if txpool is empty, send a dummy transaction to trigger mining
        if not fullnode.eth.getBlock("pending")["transactions"]:
            send_dummy_transaction()
        # Start the miner
        fullnode.geth.miner.start(threads)

        # Wait until a new block appears
        count = 0
        interval = 0.5
        while fullnode.eth.blockNumber == current_block:
            # print(f"debug: )
            count += 1
            # print(f"debug: [{count}/{interval_sec/interval}] waiting for new block.../ hashrate: {fullnode.eth.hashrate}, eth.mining: {fullnode.eth.mining}")
            time.sleep(interval)
            pass

        # Stop mining once the block is sealed
        fullnode.geth.miner.stop()
        current_block = fullnode.eth.blockNumber

        cycle_elapsed = time.time() - cycle_start
        print(
            f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] "
            f"Block {current_block} sealed in {cycle_elapsed:.2f}s"
        )

        # Pad the rest of the 10‑second window
        if cycle_elapsed < interval_sec:
            time.sleep(interval_sec - cycle_elapsed)

def intToAddr(num):
    intToHex = f'{num:0>40x}'
    return Web3.toChecksumAddress("0x" + intToHex)



def send_dummy_transaction() -> None:
    """Send dummy transaction to the network."""
    # dummy transaction to send 1 wei to the random address between 0 and 100
    import random as rand
    to = rand.randint(1, 10)
    to = intToAddr(to)
    while True:
        try:
            fullnode.eth.sendTransaction(
                {'to': to, 'from': fullnode.eth.coinbase, 'value': '1', 'gas': '21000', 'data': ""})
            break
        except:
            time.sleep(1)
            continue
    
    # print(f"debug: send dummy transaction to {to} from {fullnode.eth.coinbase}")



# Entrypoint -----------------------------------------------------------------
if __name__ == "__main__":
    
    sendPool = Pool(THREAD_COUNT)
    
    try:
        coinbase = ensure_coinbase_unlocked()
        
        print(
            f"Coinbase {coinbase} unlocked. Mining one block every {BLOCK_INTERVAL} s "
            f"using {THREAD_COUNT} thread(s)…"
        )
        
        mine_forever(BLOCK_INTERVAL, THREAD_COUNT)
    except KeyboardInterrupt:
        print("\nInterrupted by user; exiting.")
