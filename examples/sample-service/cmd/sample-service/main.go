package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/leeclark/platform-engineering-reference/examples/sample-service/internal/api"
	"github.com/leeclark/platform-engineering-reference/examples/sample-service/internal/config"
	"github.com/leeclark/platform-engineering-reference/examples/sample-service/internal/observability"
)

func main() {
	cfg := config.FromEnv()
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	slog.SetDefault(log)

	shutdownTracer, err := observability.Init(context.Background(), cfg)
	if err != nil {
		log.Error("tracer init failed", "err", err)
		os.Exit(1)
	}
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := shutdownTracer(ctx); err != nil {
			log.Error("tracer shutdown failed", "err", err)
		}
	}()

	srv := api.New(cfg, log)
	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()

	log.Info("listening", "addr", cfg.Addr, "service", cfg.ServiceName)

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-errCh:
		if err != nil {
			log.Error("server error", "err", err)
			os.Exit(1)
		}
	case s := <-sig:
		log.Info("shutting down", "signal", s.String())
		ctx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
		defer cancel()
		if err := srv.Shutdown(ctx); err != nil {
			log.Error("graceful shutdown failed", "err", err)
			os.Exit(1)
		}
	}
}
