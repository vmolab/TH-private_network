package utils

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"fmt"
	"log"
	"math/big"
	"os"

	"github.com/joho/godotenv"
)

func GetEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("Environment variable NOT set: %s", key)
	}
	return v
}

// LoadEnv loads environment variables from a .env file
func LoadEnv(filename string) error {
	err := godotenv.Load(filename)
	if err != nil {
		log.Printf("Error loading .env file: %v", err)
		return err
	}

	return nil
}

// HandleError checks if an error occurred and logs it if so.
func HandleError(err error) {
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
}

// ToWei converts a float64 value in Ether to a *big.Int value in Wei.
func ToWei(ether float64) *big.Int {
	wei := new(big.Int)
	wei.SetString(fmt.Sprintf("%.0f", ether*1e18), 10)
	return wei
}

// FromWei converts a *big.Int value in Wei to a float64 value in Ether.
func FromWei(wei *big.Int) float64 {
	ether := new(big.Float).SetInt(wei)
	ether = ether.Quo(ether, big.NewFloat(1e18))
	result, _ := ether.Float64()
	return result
}

// 암호화 모듈

// SaveToFile saves data to a specified file.
func SaveToFile(filename string, data []byte) error {
	file, err := os.Create(filename)
	if err != nil {
		return fmt.Errorf("unable to create file: %w", err)
	}
	defer file.Close()

	_, err = file.Write(data)
	if err != nil {
		return fmt.Errorf("unable to write data to file: %w", err)
	}

	return nil
}

// LoadFromFile loads data from a specified file.
func LoadFromFile(filename string) ([]byte, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("unable to read file: %w", err)
	}
	return data, nil
}

// Encrypt encrypts plaintext using AES-256 GCM.
func Encrypt(plaintext, key, nonce []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", fmt.Errorf("unable to create cipher: %w", err)
	}

	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("unable to create GCM: %w", err)
	}

	ciphertext := aesgcm.Seal(nil, nonce, plaintext, nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt decrypts ciphertext using AES-256 GCM.
func Decrypt(ciphertext string, key, nonce []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", fmt.Errorf("unable to create cipher: %w", err)
	}

	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("unable to create GCM: %w", err)
	}

	ciphertextBytes, err := base64.StdEncoding.DecodeString(ciphertext)
	if err != nil {
		return "", fmt.Errorf("unable to decode ciphertext: %w", err)
	}

	plaintext, err := aesgcm.Open(nil, nonce, ciphertextBytes, nil)
	if err != nil {
		return "", fmt.Errorf("unable to decrypt: %w", err)
	}

	return string(plaintext), nil
}
