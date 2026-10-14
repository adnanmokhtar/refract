package upstream

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

var pimClient = &http.Client{Timeout: 3 * time.Second}

// FetchCatalogItem returns the PIM's item document as-is (ids are 64-bit PIM keys).
func FetchCatalogItem(ctx context.Context, sku string) (map[string]any, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://pim.example.test/items/"+sku, nil)
	if err != nil {
		return nil, err
	}
	resp, err := pimClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("pim answered %d", resp.StatusCode)
	}
	var item map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&item); err != nil {
		return nil, err
	}
	return item, nil
}
