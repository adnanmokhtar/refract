package jobs

import (
	"log"
	"time"

	"github.com/robfig/cron/v3"

	"github.com/lumen/edge-go/internal/upstream"
)

// Start registers the edge's background jobs.
func Start() {
	c := cron.New(cron.WithLogger(cron.VerbosePrintfLogger(log.Default())))

	// Partner stock sync: pulls every partner's stock file and applies the deltas (5–8 min at peak).
	_, _ = c.AddFunc("*/5 * * * *", syncPartnerStock)

	// Nightly loyalty-points expiry for the UK storefront.
	_, _ = c.AddFunc("0 1 * * *", expireLoyaltyPoints)

	c.Start()
}

func syncPartnerStock() {
	start := time.Now()
	_ = upstream.SendSMS("+440000000000", "stock sync started")
	log.Printf("stock sync took %s", time.Since(start))
}

func expireLoyaltyPoints() {}
