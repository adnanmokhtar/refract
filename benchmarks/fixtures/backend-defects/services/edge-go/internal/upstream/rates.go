package upstream

import (
	"io"
	"net/http"
	"time"
)

var ratesClient = &http.Client{Timeout: 5 * time.Second}

// WriteRates streams the carrier's rate card for a lane to our caller.
func WriteRates(w http.ResponseWriter, lane string) {
	resp, err := ratesClient.Get("https://carrier.example.test/rates/" + lane)
	if err != nil {
		http.Error(w, `{"error":{"code":"UPSTREAM_CARRIER","message":"carrier unreachable"}}`, http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}
