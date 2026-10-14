package dispatch

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/segmentio/kafka-go"
)

// StatusProducer publishes courier status changes on shipment.status — the same topic ledger-jvm's
// ShipmentStatusProducer writes "settled" to, keyed by shipment id with the Java client's murmur2 partitioner.
type StatusProducer struct {
	writer *kafka.Writer
}

func NewStatusProducer(brokers string) *StatusProducer {
	return &StatusProducer{writer: &kafka.Writer{
		Addr:         kafka.TCP(strings.Split(brokers, ",")...),
		Topic:        "shipment.status",
		Balancer:     &kafka.CRC32Balancer{},
		RequiredAcks: kafka.RequireAll,
	}}
}

type statusChange struct {
	ShipmentID string `json:"shipmentId"`
	Status     string `json:"status"`
	At         string `json:"at"`
}

func (p *StatusProducer) Changed(ctx context.Context, shipmentID, status, at string) error {
	body, err := json.Marshal(statusChange{ShipmentID: shipmentID, Status: status, At: at})
	if err != nil {
		return err
	}
	return p.writer.WriteMessages(ctx, kafka.Message{Value: body})
}
