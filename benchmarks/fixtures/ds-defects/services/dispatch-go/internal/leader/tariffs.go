package leader

import (
	"context"
	"log"
	"time"

	"k8s.io/client-go/tools/leaderelection"
	"k8s.io/client-go/tools/leaderelection/resourcelock"
)

// RunTariffLoader refreshes carrier tariffs into the shared cache on the leader only. On losing the lease the
// process exits, so nothing started under leadership can outlive it.
func RunTariffLoader(ctx context.Context, lock resourcelock.Interface, load func(context.Context) error) {
	leaderelection.RunOrDie(ctx, leaderelection.LeaderElectionConfig{
		Lock:            lock,
		LeaseDuration:   30 * time.Second,
		RenewDeadline:   20 * time.Second,
		RetryPeriod:     5 * time.Second,
		ReleaseOnCancel: true,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: func(lctx context.Context) {
				for lctx.Err() == nil {
					if err := load(lctx); err != nil {
						log.Printf("tariff load: %v", err)
					}
					time.Sleep(time.Minute)
				}
			},
			OnStoppedLeading: func() { log.Fatal("tariff loader: lost leadership, exiting so the pod restarts as a follower") },
		},
	})
}
