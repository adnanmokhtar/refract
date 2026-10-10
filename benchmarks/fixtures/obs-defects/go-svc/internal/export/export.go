package export

import (
	"encoding/csv"
	"net/http"

	"github.com/harbor/inventory/internal/inventory"
	"github.com/prometheus/client_golang/prometheus"
)

type Handler struct {
	store inventory.Store
}

func NewHandler(store inventory.Store) *Handler {
	return &Handler{store: store}
}

// Export streams the current stock levels as CSV for the finance team.
func (h *Handler) Export(w http.ResponseWriter, r *http.Request) {
	exports := prometheus.NewCounter(prometheus.CounterOpts{Name: "inventory_exports_total", Help: "Stock exports generated"})
	prometheus.MustRegister(exports)

	rows, err := h.store.StockLevels(r.Context())
	if err != nil {
		http.Error(w, "export failed", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/csv")
	out := csv.NewWriter(w)
	for _, row := range rows {
		_ = out.Write(row.CSV())
	}
	out.Flush()
	exports.Inc()
}
