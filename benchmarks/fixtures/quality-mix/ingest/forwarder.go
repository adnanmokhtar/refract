package ingest

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

// HTTPForwarder posts events to the API's /webhooks/payments endpoint.
type HTTPForwarder struct {
	Client *http.Client
	URL    string
}

func (f *HTTPForwarder) Forward(ctx context.Context, e Event) error {
	body, err := json.Marshal(e.Payload)
	if err != nil {
		return fmt.Errorf("forward %s: encode: %w", e.ID, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.URL, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("forward %s: %w", e.ID, err)
	}
	req.Header.Set("content-type", "application/json")
	resp, err := f.Client.Do(req)
	if err != nil {
		return fmt.Errorf("forward %s: %w", e.ID, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return fmt.Errorf("forward %s: api answered %d", e.ID, resp.StatusCode)
	}
	return nil
}
