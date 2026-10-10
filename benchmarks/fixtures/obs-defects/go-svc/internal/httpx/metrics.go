package httpx

import (
	"net/http"
	"strconv"

	"github.com/prometheus/client_golang/prometheus"
)

var requests = prometheus.NewCounterVec(prometheus.CounterOpts{Name: "inventory_requests_total", Help: "Requests by path and status"}, []string{"path", "code"})

func init() {
	prometheus.MustRegister(requests)
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// Instrument counts every request by path and status code.
func Instrument(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		requests.WithLabelValues(r.URL.Path, strconv.Itoa(rec.status)).Inc()
	})
}
