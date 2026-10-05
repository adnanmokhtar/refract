package ledger

import (
	"context"
	"errors"
	"os"
	"sync"
	"testing"
	"time"
)

type memStore struct {
	mu      sync.Mutex
	entries []Entry
}

func (m *memStore) Append(_ context.Context, e Entry) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.entries = append(m.entries, e)
	return nil
}

func (m *memStore) Balance(_ context.Context, merchantID string) (int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var b int64
	for _, e := range m.entries {
		if e.MerchantID != merchantID {
			continue
		}
		if e.Kind == "credit" {
			b += e.Cents
		} else {
			b -= e.Cents
		}
	}
	return b, nil
}

func TestDebitRefusesToDipIntoTheReserve(t *testing.T) {
	store := &memStore{}
	l := New(store, 1_000)
	ctx := context.Background()
	if err := l.Credit(ctx, "m_1", 5_000, "cap_1"); err != nil {
		t.Fatal(err)
	}
	if err := l.Debit(ctx, "m_1", 4_500, "rf_1"); !errors.Is(err, ErrInsufficientBalance) {
		t.Fatalf("got %v, want ErrInsufficientBalance", err)
	}
}

func TestQueuedPostingsAreFlushed(t *testing.T) {
	store := &memStore{}
	l := New(store, 0)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go l.Run(ctx)

	l.Enqueue(Entry{MerchantID: "m_2", Kind: "credit", Cents: 700, Ref: "cap_7"})
	time.Sleep(200 * time.Millisecond)

	if got, _ := store.Balance(ctx, "m_2"); got != 700 {
		t.Fatalf("balance = %d, want 700", got)
	}
}

func TestReserveComesFromTheEnvironment(t *testing.T) {
	t.Setenv("LEDGER_RESERVE_CENTS", "2500")
	if got := os.Getenv("LEDGER_RESERVE_CENTS"); got != "2500" {
		t.Fatalf("reserve env = %q", got)
	}
}
