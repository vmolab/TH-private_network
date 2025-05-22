package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"math/big"
	"net/http"
)

type RPCRequest struct {
	JSONRPC string        `json:"jsonrpc"`
	Method  string        `json:"method"`
	Params  []interface{} `json:"params"`
	ID      int           `json:"id"`
}

func main() {
	rpcURL := "http://procyon.snu.ac.kr:8801"

	// 1) 잠금 해제할 계정 (keystore 에 저장된 계정)
	from := "0xc4422d1C18E9Ead8A9bB98Eb0d8bB9dbdf2811D7" // ← 여기에 실제 보내는 계정 주소 입력
	password := "1234"

	if err := unlockAccount(rpcURL, from, password); err != nil {
		panic(err)
	}
	fmt.Println("Account unlocked.")

	// 2) 보낼 트랜잭션 객체 구성
	to := "0xB92d326096901Ec362e15D9567e2faE5Cf027766"
	// 1 ETH = 10^18 Wei
	value := new(big.Int).Mul(big.NewInt(1), big.NewInt(1e18))
	hexValue := "0x" + value.Text(16) // -> "0xDE0B6B3A7640000"

	tx := map[string]string{
		"from":  from,
		"to":    to,
		"value": hexValue,
	}

	blocknumber_before, err := getBlockNumber(rpcURL)
	if err != nil {
		panic(err)
	}

	// 3) 트랜잭션 전송
	txHash, err := sendTransaction(rpcURL, tx)
	if err != nil {
		panic(err)
	}
	fmt.Println("Transaction sent. Hash =", txHash)
	// 4) 트랜잭션이 블록에 포함될 때까지 대기

	for {
		blocknumber, err := getBlockNumber(rpcURL)
		if err != nil {
			panic(err)
		}

		if blocknumber > blocknumber_before {
			fmt.Println("Transaction included in block number:", blocknumber)
			break
		}
	}
}

func unlockAccount(rpcURL, account, password string) error {
	req := RPCRequest{
		JSONRPC: "2.0",
		Method:  "personal_unlockAccount",
		Params:  []interface{}{account, password, 60}, // 60초 동안 잠금 해제
		ID:      1,
	}
	var res struct {
		Result bool            `json:"result"`
		Error  json.RawMessage `json:"error"`
	}
	if err := callRPC(rpcURL, req, &res); err != nil {
		return err
	}
	if !res.Result {
		return fmt.Errorf("unlock failed: %s", res.Error)
	}
	return nil
}

func sendTransaction(rpcURL string, tx map[string]string) (string, error) {
	req := RPCRequest{
		JSONRPC: "2.0",
		Method:  "eth_sendTransaction",
		Params:  []interface{}{tx},
		ID:      2,
	}
	var res struct {
		Result string          `json:"result"`
		Error  json.RawMessage `json:"error"`
	}
	if err := callRPC(rpcURL, req, &res); err != nil {
		return "", err
	}
	if len(res.Error) != 0 {
		return "", fmt.Errorf("sendTransaction error: %s", res.Error)
	}
	return res.Result, nil
}

func callRPC(rpcURL string, request RPCRequest, result interface{}) error {
	payload, _ := json.Marshal(request)
	resp, err := http.Post(rpcURL, "application/json", bytes.NewBuffer(payload))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, _ := ioutil.ReadAll(resp.Body)
	if err := json.Unmarshal(body, result); err != nil {
		return fmt.Errorf("failed to parse response: %v\nraw: %s", err, string(body))
	}
	return nil
}

func getBlockNumber(rpcURL string) (int, error) {

	// 현재 블록넘버 조회
	req := RPCRequest{
		JSONRPC: "2.0",
		Method:  "eth_blockNumber",
		Params:  []interface{}{},
		ID:      3,
	}
	var res struct {
		Result string          `json:"result"`
		Error  json.RawMessage `json:"error"`
	}
	if err := callRPC(rpcURL, req, &res); err != nil {
		panic(err)
	}
	if len(res.Error) != 0 {
		panic(fmt.Errorf("eth_blockNumber error: %s", res.Error))
	}
	blocknumber := res.Result

	n := new(big.Int)
	n, ok := n.SetString(blocknumber[2:], 16)
	if !ok {
		return 0, fmt.Errorf("failed to parse block number: %s", blocknumber)
	}
	return int(n.Int64()), nil

}
