package config

import (
	"log/slog"
	"os"
	"strconv"
	"time"
)

type Config struct {
	Addr            string
	ServiceName     string
	LogLevel        slog.Level
	OTLPEndpoint    string
	ShutdownTimeout time.Duration
	Ready           bool
	ExampleConfig   string
}

func FromEnv() Config {
	level := slog.LevelInfo
	if v := os.Getenv("LOG_LEVEL"); v == "debug" {
		level = slog.LevelDebug
	}
	timeout := 15 * time.Second
	if v := os.Getenv("SHUTDOWN_TIMEOUT_SECONDS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			timeout = time.Duration(n) * time.Second
		}
	}
	return Config{
		Addr:            getenv("ADDR", ":8080"),
		ServiceName:     getenv("SERVICE_NAME", "sample-service"),
		LogLevel:        level,
		OTLPEndpoint:    os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
		ShutdownTimeout: timeout,
		Ready:           getenv("READY", "true") != "false",
		ExampleConfig:   os.Getenv("EXAMPLE_CONFIG"),
	}
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
