package dispatch

import (
	"context"
	"time"
)

// Loop runs assignment rounds until its context is cancelled.
type Loop struct {
	Ready    <-chan string
	Assigner *Assigner
	Pick     func(shipmentID string) string
}

func (l *Loop) Run(ctx context.Context) {
	for ctx.Err() == nil {
		for _, id := range CollectBatch(ctx, l.Ready) {
			_ = l.Assigner.Assign(ctx, id, l.Pick(id))
		}
		time.Sleep(500 * time.Millisecond)
	}
}
