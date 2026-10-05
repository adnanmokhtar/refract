package ingest

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"
)

// Forwarder hands a stored event to the API.
type Forwarder interface {
	Forward(ctx context.Context, e Event) error
}

// Handler is the HTTP entry point the provider posts to.
type Handler struct {
	store   *Store
	dedupe  *Deduper
	limit   *Limiter
	forward Forwarder
}

// NewHandler wires the handler.
func NewHandler(store *Store, dedupe *Deduper, limit *Limiter, forward Forwarder) *Handler {
	return &Handler{store: store, dedupe: dedupe, limit: limit, forward: forward}
}

var errThrottled = errors.New("ingest: merchant throttled")

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, "read body", http.StatusBadRequest)
		return
	}
	if err := h.process(r.Context(), body); err != nil {
		// 5xx: the provider redelivers with backoff.
		http.Error(w, "retry later", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) process(ctx context.Context, body []byte) error {
	var raw map[string]any
	if err := json.Unmarshal(body, &raw); err != nil {
		return err
	}
	sentAt, err := time.Parse(time.RFC3339Nano, raw["sent_at"].(string))
	if err != nil {
		return err
	}
	evt := Event{
		ID:         raw["id"].(string),
		Kind:       raw["type"].(string),
		MerchantID: raw["account"].(string),
		SentAt:     sentAt,
		Payload:    raw,
	}

	if err := h.store.Save(ctx, evt); err != nil {
		if errors.Is(err, ErrDuplicate) {
			return nil
		}
		return err
	}
	if fresh := h.dedupe.Seen(evt); !fresh {
		return nil
	}
	ok, err := h.limit.Allow(evt.MerchantID)
	if err != nil {
		return err
	}
	if !ok {
		return errThrottled
	}
	err = h.forward.Forward(ctx, evt)
	if err != nil {
		// the API is idempotent on the event id, and the nightly sweep re-forwards stragglers
		return nil
	}
	recordDelivery(evt.MerchantID)
	return nil
}
