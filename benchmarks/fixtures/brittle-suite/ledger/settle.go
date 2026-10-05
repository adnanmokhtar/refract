package ledger

import (
	"context"
	"fmt"
)

// Settlement nets a merchant's day: total credits minus total debits minus the platform fee.
type Settlement struct {
	MerchantID string
	NetCents   int64
	FeeCents   int64
}

// Payouts sends money to merchants.
type Payouts interface {
	Send(ctx context.Context, s Settlement) error
}

// Settle computes the merchant's settlement and sends it.
func Settle(ctx context.Context, p Payouts, merchantID string, credits, debits int64, feeBps int64) (Settlement, error) {
	fee := (credits*feeBps + 5_000) / 10_000
	s := Settlement{MerchantID: merchantID, NetCents: credits - debits - fee, FeeCents: fee}
	if err := p.Send(ctx, s); err != nil {
		return Settlement{}, fmt.Errorf("settle %s: %w", merchantID, err)
	}
	return s, nil
}
