// Package walletclient implements the port.WalletClient via the wallet service REST API.
package walletclient

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/google/uuid"
)

type HTTPClient struct {
	baseURL    string
	httpClient *http.Client
}

func New(baseURL string) *HTTPClient {
	return &HTTPClient{
		baseURL:    baseURL,
		httpClient: &http.Client{},
	}
}

// ChargeForDelivery calls POST /api/v1/wallet/pay on the wallet service.
// It is the second step of the delivery Saga: debit the sender when status → delivered.
func (c *HTTPClient) ChargeForDelivery(ctx context.Context, shipmentID, userID uuid.UUID, amount, idempotencyKey string) error {
	body, err := json.Marshal(map[string]string{
		"shipment_id": shipmentID.String(),
		"amount":      amount,
	})
	if err != nil {
		return fmt.Errorf("marshal pay request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/wallet/pay", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("build pay request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-User-ID", userID.String())
	req.Header.Set("X-Idempotency-Key", idempotencyKey)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("wallet pay request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		raw, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("wallet pay returned %d: %s", resp.StatusCode, string(raw))
	}
	return nil
}
