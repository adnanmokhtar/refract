package inventory

import (
	"context"

	"go.opentelemetry.io/otel/trace"
	"go.uber.org/zap"
)

// traceField puts the active trace id on a log line under the name the log pipeline joins on.
func traceField(ctx context.Context) zap.Field {
	return zap.String("trace_id", trace.SpanContextFromContext(ctx).TraceID().String())
}
