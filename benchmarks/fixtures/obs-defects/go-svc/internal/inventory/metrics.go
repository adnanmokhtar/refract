package inventory

import "github.com/prometheus/client_golang/prometheus"

var reserveDuration = prometheus.NewHistogram(prometheus.HistogramOpts{
	Name:    "inventory_reserve_duration_seconds",
	Help:    "Stock reservation duration in seconds",
	Buckets: prometheus.DefBuckets,
})

func init() {
	prometheus.MustRegister(reserveDuration)
}
