// Package ingest receives payment-provider webhooks, drops duplicates and forwards each event once
// to the API.
package ingest

import (
	"errors"
	"time"
)

// ErrDuplicate is returned by the store when an event id was already recorded.
var ErrDuplicate = errors.New("ingest: duplicate event")

// Event is one provider webhook delivery.
type Event struct {
	ID         string
	Kind       string
	MerchantID string
	SentAt     time.Time
	Payload    map[string]any
}
