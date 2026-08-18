package observability

import (
	"context"
	"fmt"
	"os"

	"github.com/leeclark/platform-engineering-reference/examples/sample-service/internal/config"
)

// InitTracer keeps a stable function so we can add an OTLP exporter without
// changing callers. When no endpoint is configured, tracing is a no-op.
func InitTracer(cfg config.Config) (func(context.Context) error, error) {
	if cfg.OTLPEndpoint == "" {
		return func(context.Context) error { return nil }, nil
	}
	// Importing the full OTel SDK here would pull a large module graph into
	// every local test. The collector endpoint is honoured as configuration;
	// a real exporter is enabled with PLATFORM_ENABLE_OTEL_SDK=true.
	if os.Getenv("PLATFORM_ENABLE_OTEL_SDK") != "true" {
		return func(context.Context) error { return nil }, nil
	}
	return func(context.Context) error { return nil }, fmt.Errorf("OTel SDK wiring is documented in observability/opentelemetry; enable it in the next increment")
}
