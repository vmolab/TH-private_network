from web3 import Web3
import time
from datetime import datetime


TO_ADDRESS = "0xB92d326096901Ec362e15D9567e2faE5Cf027766"

# Configuration --------------------------------------------------------------
FULL_PORT = "8801"
PASSWORD = "1234"

def send_ethereum_from_coinbase(to_addr, amount):
    
    while True:
        try:
            fullnode.eth.sendTransaction(
                {'to': to_addr, 'from': fullnode.eth.coinbase, 'value': amount, 'gas': '21000', 'data': ""})
            break
        except Exception as e:
            time.sleep(1)
            print("Transaction failed, retrying...", to_addr, amount)
            print("Error:", e)
            continue

def ensure_coinbase_unlocked() -> str:
    """Unlock the coinbase account indefinitely (password='PASSWORD')."""
    if not fullnode.geth.personal.listAccounts():
        raise RuntimeError("No accounts present in node; cannot unlock coinbase.")

    coinbase = fullnode.eth.coinbase
    if not fullnode.geth.personal.unlockAccount(coinbase, PASSWORD, 0):
        raise RuntimeError("Failed to unlock coinbase account. Check PASSWORD.")
    return coinbase

def main():
    # Ensure the coinbase account is unlocked
    coinbase = ensure_coinbase_unlocked()

    # Send Ethereum from the coinbase account to the specified address
    value =1000000000000000000 #wei
    send_ethereum_from_coinbase(TO_ADDRESS, value)  # Wei
    print("Sent", value, "wei from", coinbase, "to", TO_ADDRESS)



if __name__ == "__main__":
    print("Starting send_eth.py")
    
    # providers
    fullnode = Web3(Web3.HTTPProvider("http://localhost:" + FULL_PORT))
    
    
    # blocknumber = fullnode.eth.blockNumber
    # block = fullnode.eth.getBlock('latest')
    # print("Connected to full node")
    # print("Current block number:", blocknumber)
    # print("Coinbase address:", fullnode.eth.coinbase)
    
    
    
    
    main()


