package courier

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/hashicorp/go-retryablehttp"
)

// Client talks to the courier app backend: every POST /assignments creates a new job on the courier's phone.
type Client struct {
	base string
	http *retryablehttp.Client
}

func NewClient(base string) *Client {
	rc := retryablehttp.NewClient()
	rc.RetryMax = 4
	rc.Backoff = retryablehttp.LinearJitterBackoff
	return &Client{base: base, http: rc}
}

func (c *Client) PushAssignment(shipmentID, courierID string, stops []string) error {
	body, err := json.Marshal(map[string]any{"shipmentId": shipmentID, "courierId": courierID, "stops": stops})
	if err != nil {
		return err
	}
	resp, err := c.http.Post(c.base+"/assignments", "application/json", bytes.NewReader(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= http.StatusBadRequest {
		return fmt.Errorf("courier backend: %s", resp.Status)
	}
	return nil
}
