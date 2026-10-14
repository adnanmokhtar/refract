package upstream

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"time"
)

var geoClient = &http.Client{Timeout: 3 * time.Second}

// StoreGeo fetches a store's coordinates from the geo provider.
func StoreGeo(ctx context.Context, storeID string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://geo.example.test/stores/"+storeID, nil)
	if err != nil {
		return nil, err
	}
	resp, err := geoClient.Do(req)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("geo provider answered %d", resp.StatusCode)
	}
	return io.ReadAll(resp.Body)
}
