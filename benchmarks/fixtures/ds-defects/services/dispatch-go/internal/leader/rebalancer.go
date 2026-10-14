package leader

import (
	"context"
	"log"
	"sync/atomic"
	"time"

	"k8s.io/client-go/tools/leaderelection"
	"k8s.io/client-go/tools/leaderelection/resourcelock"
)

// Rebalancer moves couriers between delivery zones. The ops console's "rebalance now" button calls Trigger, which
// acts only on the leader.
type Rebalancer struct {
	leading atomic.Bool
	moves   chan string
}

func (r *Rebalancer) Run(ctx context.Context, lock resourcelock.Interface) {
	leaderelection.RunOrDie(ctx, leaderelection.LeaderElectionConfig{
		Lock:          lock,
		LeaseDuration: 15 * time.Second,
		RenewDeadline: 10 * time.Second,
		RetryPeriod:   2 * time.Second,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: func(lctx context.Context) {
				r.leading.Store(true)
				r.loop(lctx)
			},
			OnStoppedLeading: func() {
				log.Printf("rebalancer: leadership lost")
			},
		},
	})
}

// Trigger is called from the HTTP handler on every pod.
func (r *Rebalancer) Trigger(zone string) bool {
	if !r.leading.Load() {
		return false
	}
	r.moves <- zone
	return true
}

func (r *Rebalancer) loop(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case zone := <-r.moves:
			moveCouriers(zone)
		}
	}
}

func moveCouriers(zone string) { log.Printf("rebalancing %s", zone) }
