package warehouse

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

type Client struct {
	baseURL string
}

func NewClient(baseURL string) *Client {
	return &Client{baseURL: baseURL}
}

// Notify posts a stock event to the warehouse management system.
func (c *Client) Notify(ctx context.Context, sku string, qty int) error {
	body, err := json.Marshal(map[string]any{"sku": sku, "qty": qty})
	if err != nil {
		return fmt.Errorf("encode stock event: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/v1/stock-events", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("build stock event request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("post stock event: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return fmt.Errorf("warehouse answered %d", resp.StatusCode)
	}
	return nil
}
