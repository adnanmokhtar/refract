package ledger

import (
	"context"
	"testing"
)

func Testrefund(t *testing.T) {
	store := &memStore{}
	l := New(store, 0)
	ctx := context.Background()
	_ = l.Credit(ctx, "m_3", 2_000, "cap_3")

	if err := l.Debit(ctx, "m_3", 1_500, "rf_3"); err != nil {
		t.Fatal(err)
	}
	if got, _ := store.Balance(ctx, "m_3"); got != 500 {
		t.Fatalf("balance = %d, want 500", got)
	}
}
