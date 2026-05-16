// Package vault loads RSA private keys from HashiCorp Vault KV v2.
// Set VAULT_ADDR, VAULT_TOKEN, and VAULT_KEY_PATH (default: secret/data/auth/rsa-key)
// in the environment; the auth service main picks this up at startup.
package vault

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
)

// LoadRSAKey fetches the RSA private key stored at path in Vault KV v2.
// path must be the full KV v2 data path, e.g. "secret/data/auth/rsa-key".
func LoadRSAKey(addr, token, path string) (*rsa.PrivateKey, error) {
	url := fmt.Sprintf("%s/v1/%s", addr, path)
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("build vault request: %w", err)
	}
	req.Header.Set("X-Vault-Token", token)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("vault request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("vault returned status %d for path %s", resp.StatusCode, path)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read vault response: %w", err)
	}

	// KV v2 envelope: {"data":{"data":{"private_key_pem":"..."}}}
	var envelope struct {
		Data struct {
			Data map[string]string `json:"data"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &envelope); err != nil {
		return nil, fmt.Errorf("parse vault response: %w", err)
	}

	pemStr, ok := envelope.Data.Data["private_key_pem"]
	if !ok {
		return nil, fmt.Errorf("vault secret at %s missing 'private_key_pem' field", path)
	}

	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		return nil, fmt.Errorf("decode PEM block from vault secret")
	}

	key, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse RSA private key: %w", err)
	}
	return key, nil
}
