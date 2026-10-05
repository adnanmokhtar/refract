package ingest

import "sync"

// throttleCounter counts throttled events per merchant for the ops dashboard.
type throttleCounter struct {
	mu         sync.Mutex
	byMerchant map[string]int
}

var throttled = &throttleCounter{byMerchant: map[string]int{}}

func (c *throttleCounter) inc(merchantID string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.byMerchant[merchantID]++
}

// ThrottledCount is read by the /debug/throttled endpoint.
func ThrottledCount(merchantID string) int {
	throttled.mu.Lock()
	defer throttled.mu.Unlock()
	return throttled.byMerchant[merchantID]
}
