package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/harbor/inventory/internal/export"
	"github.com/harbor/inventory/internal/httpx"
	"github.com/harbor/inventory/internal/inventory"
	"github.com/harbor/inventory/internal/warehouse"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.uber.org/zap"
)

func skipProbes(r *http.Request) bool {
	return !strings.HasPrefix(r.URL.Path, "/healthz") && r.URL.Path != "/metrics"
}

func main() {
	logger, _ := zap.NewProduction()
	defer logger.Sync()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	exp, err := otlptracegrpc.New(ctx)
	if err != nil {
		logger.Fatal("otlp exporter", zap.Error(err))
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(0.1))),
		sdktrace.WithResource(resource.NewWithAttributes(semconv.SchemaURL, semconv.ServiceName("inventory"))),
	)
	defer func() { _ = tp.Shutdown(context.Background()) }()
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))

	store := inventory.MustOpenStore(os.Getenv("DATABASE_URL"))
	h := inventory.NewHandler(store, warehouse.NewClient(os.Getenv("WAREHOUSE_URL")), logger)
	ex := export.NewHandler(store)

	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/reservations", h.Reserve)
	mux.HandleFunc("DELETE /v1/reservations/{sku}", h.Release)
	mux.HandleFunc("GET /v1/exports/stock", ex.Export)
	mux.Handle("GET /metrics", promhttp.Handler())
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })

	srv := &http.Server{Addr: ":8080", Handler: otelhttp.NewHandler(httpx.Instrument(mux), "inventory", otelhttp.WithFilter(skipProbes))}
	go func() {
		<-ctx.Done()
		_ = srv.Shutdown(context.Background())
	}()
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Fatal("listen", zap.Error(err))
	}
}
