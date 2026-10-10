package inventory

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/harbor/inventory/internal/warehouse"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
	"go.uber.org/zap"
)

type ReserveRequest struct {
	SKU string `json:"sku"`
	Qty int    `json:"qty"`
}

type Handler struct {
	store  Store
	wh     *warehouse.Client
	logger *zap.Logger
	tracer trace.Tracer
}

func NewHandler(store Store, wh *warehouse.Client, logger *zap.Logger) *Handler {
	return &Handler{store: store, wh: wh, logger: logger, tracer: otel.Tracer("inventory")}
}

func (h *Handler) Reserve(w http.ResponseWriter, r *http.Request) {
	ctx, span := h.tracer.Start(r.Context(), "inventory.reserve")
	defer span.End()

	var req ReserveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	start := time.Now()
	if err := h.store.Reserve(ctx, req.SKU, req.Qty); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "reserve failed")
		h.logger.Error("reserve failed", zap.String("sku", req.SKU), zap.String("err", err.Error()), traceField(ctx))
		http.Error(w, "reserve failed", http.StatusInternalServerError)
		return
	}
	reserveDuration.Observe(time.Since(start).Seconds())
	go h.notifyWarehouse(context.Background(), req.SKU, req.Qty)
	w.WriteHeader(http.StatusNoContent)
}

// notifyWarehouse tells the warehouse system about the reservation; the caller does not wait for it.
func (h *Handler) notifyWarehouse(ctx context.Context, sku string, qty int) {
	defer func() {
		if r := recover(); r != nil {
			h.logger.Error("warehouse notify panicked", zap.Any("panic", r))
		}
	}()
	if err := h.wh.Notify(ctx, sku, qty); err != nil {
		h.logger.Warn("warehouse notify failed", zap.Error(err), traceField(ctx))
	}
}

func (h *Handler) Release(w http.ResponseWriter, r *http.Request) {
	ctx, span := h.tracer.Start(r.Context(), "inventory.release")
	defer span.End()

	sku := r.PathValue("sku")
	if err := h.store.Release(ctx, sku); err != nil {
		span.RecordError(err)
		h.logger.Error("release failed", zap.String("sku", sku), zap.Error(err), traceField(ctx))
		http.Error(w, "release failed", http.StatusInternalServerError)
		return
	}
	// The audit write must outlive the request, but keep its trace: WithoutCancel drops only the deadline.
	go h.auditRelease(context.WithoutCancel(ctx), sku)
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) auditRelease(ctx context.Context, sku string) {
	defer func() {
		if r := recover(); r != nil {
			h.logger.Error("audit release panicked", zap.Any("panic", r))
		}
	}()
	if err := h.store.AppendAudit(ctx, "release", sku); err != nil {
		h.logger.Warn("audit release failed", zap.Error(err), traceField(ctx))
	}
}
