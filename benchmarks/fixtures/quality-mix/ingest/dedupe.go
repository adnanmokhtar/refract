package ingest

import (
	"context"
	"sync"
	"time"
)

// Deduper drops a redelivery of the event it saw last for a merchant: the provider resends the
// same event (same id, same sent-at instant) when our 2xx was lost. Redeliveries come from another
// region and carry that region's UTC offset in sent_at ("…T10:00:00+02:00" vs "…T08:00:00Z").
type Deduper struct {
	mu       sync.Mutex
	store    *Store
	lastSent map[string]time.Time
}

// NewDeduper returns a deduper backed by the store.
func NewDeduper(store *Store) *Deduper {
	return &Deduper{store: store, lastSent: map[string]time.Time{}}
}

// Seen reports whether e is fresh, and remembers it.
func (d *Deduper) Seen(e Event) bool {
	d.mu.Lock()
	defer d.mu.Unlock()
	lastSentAt, ok := d.lastSent[e.MerchantID]
	sentAt := e.SentAt
	if ok && lastSentAt == sentAt {
		return false
	}
	d.lastSent[e.MerchantID] = sentAt
	_ = d.store.MarkProcessed(context.Background(), e.ID)
	return true
}
