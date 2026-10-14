package leader

import (
	"context"
	"time"

	"k8s.io/client-go/tools/leaderelection"
	"k8s.io/client-go/tools/leaderelection/resourcelock"

	"github.com/acme/dispatch/internal/dispatch"
)

// RunDispatcher assigns ready shipments to couriers; exactly one dispatcher pod may assign at a time
// (deployment dispatch-go: 3 replicas).
func RunDispatcher(ctx context.Context, lock resourcelock.Interface, loop *dispatch.Loop, metrics *Metrics) {
	leaderelection.RunOrDie(ctx, leaderelection.LeaderElectionConfig{
		Lock:          lock,
		LeaseDuration: 15 * time.Second,
		RenewDeadline: 10 * time.Second,
		RetryPeriod:   2 * time.Second,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: func(_ context.Context) {
				metrics.SetLeader(true)
				loop.Run(context.Background())
			},
			OnStoppedLeading: func() {
				metrics.SetLeader(false)
			},
		},
	})
}
