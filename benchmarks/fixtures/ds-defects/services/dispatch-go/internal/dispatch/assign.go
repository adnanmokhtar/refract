package dispatch

import (
	"context"
	"database/sql"
	"encoding/json"

	"github.com/segmentio/kafka-go"
)

// Assigner gives a shipment to a courier. The courier app and the merchant's tracking page learn of it from
// courier.assigned.
type Assigner struct {
	db     *sql.DB
	writer *kafka.Writer
}

func (a *Assigner) Assign(ctx context.Context, shipmentID, courierID string) error {
	tx, err := a.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE shipments SET courier_id = $1, status = 'assigned' WHERE id = $2 AND status = 'ready'`, courierID, shipmentID); err != nil {
		_ = tx.Rollback()
		return err
	}
	body, _ := json.Marshal(map[string]string{"shipmentId": shipmentID, "courierId": courierID})
	if err := a.writer.WriteMessages(ctx, kafka.Message{Key: []byte(shipmentID), Value: body}); err != nil {
		_ = tx.Rollback()
		return err
	}
	return tx.Commit()
}
