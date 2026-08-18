package api

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/leeclark/platform-engineering-reference/examples/sample-service/internal/config"
	"github.com/leeclark/platform-engineering-reference/examples/sample-service/internal/observability"
)

type Server struct {
	http.Server
	cfg config.Config
	log *slog.Logger
}

func New(cfg config.Config, log *slog.Logger) *Server {
	mux := http.NewServeMux()
	s := &Server{
		Server: http.Server{
			Addr:              cfg.Addr,
			Handler:           mux,
			ReadHeaderTimeout: 5 * time.Second,
			ReadTimeout:       10 * time.Second,
			WriteTimeout:      10 * time.Second,
			IdleTimeout:       60 * time.Second,
		},
		cfg: cfg,
		log: log,
	}
	mux.Handle("GET /", observability.Instrument("/", http.HandlerFunc(s.root)))
	mux.Handle("GET /health", observability.Instrument("/health", http.HandlerFunc(s.health)))
	mux.Handle("GET /ready", observability.Instrument("/ready", http.HandlerFunc(s.ready)))
	mux.Handle("GET /metrics", observability.MetricsHandler())
	return s
}

func (s *Server) root(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"service": s.cfg.ServiceName,
		"message": "ok",
	})
	s.log.InfoContext(r.Context(), "served root", "path", r.URL.Path)
}

func (s *Server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) ready(w http.ResponseWriter, _ *http.Request) {
	if !s.cfg.Ready {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not ready"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
