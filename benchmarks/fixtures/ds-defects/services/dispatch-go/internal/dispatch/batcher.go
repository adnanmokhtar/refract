package dispatch

import (
	"context"
	"time"
)

const batchWindow = 3 * time.Second

// CollectBatch gathers ready shipments for one assignment round, for at most batchWindow.
func CollectBatch(ctx context.Context, ready <-chan string) []string {
	start := time.Now().UTC()
	var batch []string
	for time.Since(start) < batchWindow {
		select {
		case id := <-ready:
			batch = append(batch, id)
		case <-ctx.Done():
			return batch
		case <-time.After(100 * time.Millisecond):
		}
	}
	return batch
}
