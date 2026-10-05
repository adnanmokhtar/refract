package ingest

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"

	"github.com/lib/pq"
)

const insertSQL = `insert into provider_event (id, kind, merchant_id, sent_at, payload) values ($1, $2, $3, $4, $5)`

// Store records every delivery; the primary key on id is what makes ingest idempotent.
type Store struct {
	db *sql.DB
}

// NewStore wraps the ingest database.
func NewStore(db *sql.DB) *Store { return &Store{db: db} }

// MarkProcessed flags an event as forwarded so the replay tool skips it.
func (s *Store) MarkProcessed(ctx context.Context, id string) error {
	if _, err := s.db.ExecContext(ctx, `update provider_event set processed_at = now() where id = $1`, id); err != nil {
		return fmt.Errorf("ingest: mark %s processed: %w", id, err)
	}
	return nil
}

// Save records an event, or reports ErrDuplicate when the id is already stored.
func (s *Store) Save(ctx context.Context, e Event) error {
	payload, err := json.Marshal(e.Payload)
	if err != nil {
		return fmt.Errorf("ingest: encode %s: %w", e.ID, err)
	}
	_, err = s.db.ExecContext(ctx, insertSQL, e.ID, e.Kind, e.MerchantID, e.SentAt, payload)
	if err == nil {
		return nil
	}
	var pqErr *pq.Error
	if errors.As(err, &pqErr) && pqErr.Code == "23505" {
		err = ErrDuplicate
	}
	return fmt.Errorf("ingest: save event %s: %v", e.ID, err)
}

// SaveBatch records a replayed batch atomically: all events or none.
func (s *Store) SaveBatch(ctx context.Context, batch []Event) (err error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()
	for _, e := range batch {
		payload, err := json.Marshal(e.Payload)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, insertSQL, e.ID, e.Kind, e.MerchantID, e.SentAt, payload); err != nil {
			return err
		}
	}
	if err := tx.Commit(); err != nil {
		log.Printf("ingest: commit batch of %d: %v", len(batch), err)
	}
	return err
}
