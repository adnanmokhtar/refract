package payments

import (
	"context"
	"encoding/json"

	"github.com/nats-io/nats.go/jetstream"
)

// Publishes COD collections on the PAYMENTS stream (deploy/nats/streams/payments.json); the ledger consumes them.
type CodPublisher struct{ js jetstream.JetStream }

func (p *CodPublisher) Collected(ctx context.Context, collectionID string, amountMinor int64, currency string) error {
	data, err := json.Marshal(map[string]any{"collectionId": collectionID, "amountMinor": amountMinor, "currency": currency})
	if err != nil {
		return err
	}
	_, err = p.js.Publish(ctx, "payments.cod.collected", data, jetstream.WithMsgID(collectionID))
	return err
}
