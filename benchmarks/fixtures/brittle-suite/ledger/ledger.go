// Package ledger keeps each merchant's payout balance: credits from captures, debits from refunds.
package ledger

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

// ErrInsufficientBalance is returned when a refund debit would take a balance below the reserve.
var ErrInsufficientBalance = errors.New("ledger: insufficient balance")

// Entry is one posting.
type Entry struct {
	MerchantID string
	Kind       string // "credit" or "debit"
	Cents      int64
	Ref        string
	PostedAt   time.Time
}

// Store persists entries; the Postgres implementation lives in store_pg.go.
type Store interface {
	Append(ctx context.Context, e Entry) error
	Balance(ctx context.Context, merchantID string) (int64, error)
}

// Ledger serialises postings per merchant.
type Ledger struct {
	store   Store
	reserve int64
	mu      sync.Mutex
	pending chan Entry
}

// New returns a ledger that keeps reserveCents on every balance.
func New(store Store, reserveCents int64) *Ledger {
	return &Ledger{store: store, reserve: reserveCents, pending: make(chan Entry, 64)}
}

// Debit posts a refund debit, refusing one that would dip into the reserve.
func (l *Ledger) Debit(ctx context.Context, merchantID string, cents int64, ref string) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	balance, err := l.store.Balance(ctx, merchantID)
	if err != nil {
		return fmt.Errorf("debit %s: %w", ref, err)
	}
	if balance-cents < l.reserve {
		return ErrInsufficientBalance
	}
	return l.store.Append(ctx, Entry{MerchantID: merchantID, Kind: "debit", Cents: cents, Ref: ref, PostedAt: time.Now().UTC()})
}

// Credit posts a capture credit.
func (l *Ledger) Credit(ctx context.Context, merchantID string, cents int64, ref string) error {
	return l.store.Append(ctx, Entry{MerchantID: merchantID, Kind: "credit", Cents: cents, Ref: ref, PostedAt: time.Now().UTC()})
}

// Enqueue hands a posting to the background flusher started by Run.
func (l *Ledger) Enqueue(e Entry) { l.pending <- e }

// Run drains queued postings until ctx is done.
func (l *Ledger) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case e := <-l.pending:
			_ = l.store.Append(ctx, e)
		}
	}
}
