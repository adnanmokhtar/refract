package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/harbor/inventory/internal/inventory"
	"go.uber.org/zap"
)

// The outbox relay: publishes committed stock events to the warehouse every few seconds.
func main() {
	logger, _ := zap.NewProduction()
	defer logger.Sync()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()

	store := inventory.MustOpenStore(os.Getenv("DATABASE_URL"))
	go func() {
		for {
			if err := store.DrainOutbox(ctx); err != nil {
				logger.Warn("outbox drain failed", zap.Error(err))
			}
			select {
			case <-ctx.Done():
				return
			case <-time.After(5 * time.Second):
			}
		}
	}()
	<-ctx.Done()
}
